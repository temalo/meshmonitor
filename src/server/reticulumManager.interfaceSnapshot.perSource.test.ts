/** #6121: full interface snapshots must retire missing interfaces on their own source. */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Router } from 'express';
import type { SQLiteDatabase } from '../db/drivers/sqlite.js';
import { reticulumInterfacesSqlite } from '../db/schema/reticulum.js';
import { ReticulumManager } from './reticulumManager.js';
import type { InterfaceStatsEntry } from './reticulumProtocol.js';
import reticulumRoutes from './routes/reticulumRoutes.js';
import { createRouteTestApp, type RouteTestHarness } from './test-helpers/routeTestApp.js';

// No bridge connection; persistence, sessions, permissions and routes are real.
vi.mock('./sourceManagerRegistry.js', () => ({
  sourceManagerRegistry: { getManager: vi.fn() },
}));

const RADIO: InterfaceStatsEntry = {
  name: 'RNode LoRa Interface', type: 'RNodeInterface', status: 'up',
  online: true, txBytes: 100, rxBytes: 200,
};
const PEER: InterfaceStatsEntry = { ...RADIO, name: 'None', type: 'AutoInterfacePeer' };
const SAMPLE_TIME = 1_700_000_000_000;

function snapshot(manager: ReticulumManager, interfaces: InterfaceStatsEntry[], ts = SAMPLE_TIME) {
  // @ts-expect-error - exercise the private ingestion seam without connecting a radio
  return manager.handleInterfaceStats({ v: 1, type: 'interface_stats', ts, interfaces });
}

describe('Reticulum interface snapshot reconciliation (#6121)', () => {
  let harness: RouteTestHarness;
  let manager: ReticulumManager;

  beforeEach(async () => {
    harness = await createRouteTestApp({
      mount: app => {
        const sources = Router();
        sources.use('/:id/reticulum', reticulumRoutes);
        app.use('/api/sources', sources);
      },
    });
    // These inventory rows have no source FK cascade; the singleton outlives each test.
    await (harness.db.getDrizzleDb() as SQLiteDatabase).delete(reticulumInterfacesSqlite);
    await harness.grant(harness.limited.id, 'nodes', 'read', harness.sourceA);
    manager = new ReticulumManager(harness.sourceA);
  });

  afterEach(async () => {
    vi.restoreAllMocks();
    await harness.cleanup();
  });

  it('marks absent rows down, preserves their metadata, and counts only online interfaces on that source', async () => {
    const other = new ReticulumManager(harness.sourceB);
    await snapshot(manager, [RADIO, PEER]);
    await snapshot(other, [RADIO, PEER]);
    await harness.db.reticulum.setInterfaceRadioConfig(harness.sourceA, PEER.name, { frequency: 915_000_000 });
    const before = await harness.db.reticulum.getInterface(harness.sourceA, PEER.name);

    await snapshot(manager, [RADIO], SAMPLE_TIME + 10_000);

    expect(await harness.db.reticulum.getInterface(harness.sourceA, PEER.name)).toMatchObject({
      online: false, status: 'down', lastSeenAt: SAMPLE_TIME,
      txBytes: PEER.txBytes, rxBytes: PEER.rxBytes,
      frequency: 915_000_000, createdAt: before!.createdAt,
    });
    expect(await harness.db.reticulum.getInterface(harness.sourceB, PEER.name)).toMatchObject({ online: true, status: 'up' });
    const agent = await harness.loginAs(harness.limited);
    const status = await agent.get(`/api/sources/${harness.sourceA}/reticulum/status`);
    expect(status.status).toBe(200);
    expect(status.body.data.interfaceCount).toBe(1);
    const interfaces = await agent.get(`/api/sources/${harness.sourceA}/reticulum/interfaces`);
    expect(interfaces.status).toBe(200);
    expect(interfaces.body.data).toEqual(expect.arrayContaining([
      expect.objectContaining({ interfaceName: RADIO.name, online: true }),
      expect.objectContaining({ interfaceName: PEER.name, online: false }),
    ]));
    expect((await agent.get(`/api/sources/${harness.sourceB}/reticulum/interfaces`)).status).toBe(403);
    expect(await harness.db.reticulum.countInterfaces(harness.sourceB)).toBe(2);
  });

  it('handles an empty snapshot and seeds a fresh throughput baseline when an interface returns', async () => {
    await snapshot(manager, [RADIO]);
    const telemetry = vi.spyOn(harness.db.telemetry, 'insertTelemetryBatch');
    await snapshot(manager, [], SAMPLE_TIME + 10_000);
    expect(await harness.db.reticulum.countInterfaces(harness.sourceA)).toBe(0);
    expect(await harness.db.reticulum.getInterface(harness.sourceA, RADIO.name)).toMatchObject({ online: false, status: 'down' });

    await snapshot(manager, [{ ...RADIO, txBytes: 200, rxBytes: 400 }], SAMPLE_TIME + 20_000);
    expect(await harness.db.reticulum.countInterfaces(harness.sourceA)).toBe(1);
    expect(telemetry).not.toHaveBeenCalled();
    await snapshot(manager, [{ ...RADIO, txBytes: 300, rxBytes: 600 }], SAMPLE_TIME + 30_000);
    expect(telemetry).toHaveBeenCalledTimes(1);
  });

  it('preserves reported peer interfaces and excludes explicitly offline rows from the count', async () => {
    await snapshot(manager, [PEER, { ...RADIO, online: false, status: 'down' }]);
    expect(await harness.db.reticulum.countInterfaces(harness.sourceA)).toBe(1);
    expect(await harness.db.reticulum.getInterface(harness.sourceA, PEER.name)).toMatchObject({ online: true, interfaceType: 'AutoInterfacePeer' });
  });

  it('does not treat a reported interface as missing just because its upsert failed', async () => {
    await snapshot(manager, [RADIO, PEER]);
    vi.spyOn(harness.db.reticulum, 'upsertInterface').mockRejectedValueOnce(new Error('write failed'));
    await snapshot(manager, [RADIO], SAMPLE_TIME + 10_000);
    expect(await harness.db.reticulum.getInterface(harness.sourceA, RADIO.name)).toMatchObject({ online: true });
    expect(await harness.db.reticulum.getInterface(harness.sourceA, PEER.name)).toMatchObject({ online: false });
  });

  it('processes overlapping snapshots in arrival order, even when an older write is slow', async () => {
    let release!: () => void;
    const blocked = new Promise<void>(resolve => { release = resolve; });
    const originalUpsert = harness.db.reticulum.upsertInterface.bind(harness.db.reticulum);
    const upsert = vi.spyOn(harness.db.reticulum, 'upsertInterface').mockImplementationOnce(async (...args) => {
      await blocked;
      return originalUpsert(...args);
    });
    const retire = vi.spyOn(harness.db.reticulum, 'markMissingInterfacesOffline');
    const first = snapshot(manager, [RADIO]);
    try {
      await vi.waitFor(() => expect(upsert).toHaveBeenCalledTimes(1));
      const second = snapshot(manager, [], SAMPLE_TIME + 10_000);
      await Promise.resolve();
      expect(retire).not.toHaveBeenCalled();
      release();
      await Promise.all([first, second]);
      expect(retire.mock.calls).toEqual([
        [harness.sourceA, [RADIO.name]],
        [harness.sourceA, []],
      ]);
      expect(await harness.db.reticulum.countInterfaces(harness.sourceA)).toBe(0);
    } finally {
      release();
      await first;
    }
  });

  it('surfaces reconciliation errors without blocking subsequent snapshots', async () => {
    await snapshot(manager, [RADIO]);
    vi.spyOn(harness.db.reticulum, 'markMissingInterfacesOffline').mockRejectedValueOnce(new Error('db unavailable'));
    await expect(snapshot(manager, [], SAMPLE_TIME + 10_000)).rejects.toThrow('db unavailable');
    expect(await harness.db.reticulum.countInterfaces(harness.sourceA)).toBe(1);
    await snapshot(manager, [], SAMPLE_TIME + 20_000);
    expect(await harness.db.reticulum.countInterfaces(harness.sourceA)).toBe(0);
  });
});
