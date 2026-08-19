// @ts-check

/**
 * @typedef {object} DecodedEventRow
 * @property {string} contract_id
 * @property {string} function
 * @property {number} ledger
 * @property {string} tx_hash
 * @property {string | null} caller_address
 * @property {unknown} decoded_value
 * @property {string | null} raw_value
 */

/**
 * @typedef {object} InserterLogger
 * @property {(fields: Record<string, unknown>, msg: string) => void} error
 * @property {(fields: Record<string, unknown>, msg: string) => void} info
 */

export class EventInserter {
  /**
   * @param {import('pg').Pool | import('pg').PoolClient} db
   * @param {InserterLogger} logger
   */
  constructor(db, logger) {
    this.db = db;
    this.logger = logger;
  }

  /**
   * @param {DecodedEventRow[]} events
   * @param {string} correlationId
   * @returns {Promise<{ inserted: number, duplicates: number }>}
   */
  async insertEvents(events, correlationId) {
    const query = `
      INSERT INTO events (contract_id, function, ledger, tx_hash, caller_address, decoded_value, raw_value)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (contract_id, ledger, tx_hash) DO NOTHING
      RETURNING id
    `;

    let inserted = 0;
    let duplicates = 0;

    for (const event of events) {
      try {
        const result = await this.db.query(query, [
          event.contract_id,
          event.function,
          event.ledger,
          event.tx_hash,
          event.caller_address,
          JSON.stringify(event.decoded_value),
          event.raw_value,
        ]);

        if (result.rows.length === 0) {
          duplicates++;
        } else {
          inserted++;
        }
      } catch (err) {
        this.logger.error(
          { correlationId, error: err instanceof Error ? err.message : String(err), event },
          'Failed to insert event',
        );
      }
    }

    if (duplicates > 0) {
      this.logger.info({ correlationId, duplicates }, 'Duplicate events skipped');
    }

    return { inserted, duplicates };
  }
}

export default EventInserter;
