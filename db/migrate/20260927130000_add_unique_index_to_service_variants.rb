class AddUniqueIndexToServiceVariants < ActiveRecord::Migration[8.0]
  def up
    # 1. Reassign any room_services from duplicate variants to the canonical variant (lowest id)
    execute <<~SQL
      UPDATE room_services rs
      SET service_variant_id = canonical.min_id
      FROM (
        SELECT sv.id AS dup_id, min_sv.min_id
        FROM service_variants sv
        JOIN (
          SELECT service_id, fee, unit, is_real_time, MIN(id) AS min_id
          FROM service_variants
          GROUP BY service_id, fee, unit, is_real_time
          HAVING COUNT(*) > 1
        ) min_sv
          ON sv.service_id = min_sv.service_id
         AND sv.fee = min_sv.fee
         AND sv.unit = min_sv.unit
         AND sv.is_real_time = min_sv.is_real_time
        WHERE sv.id > min_sv.min_id
      ) canonical
      WHERE rs.service_variant_id = canonical.dup_id
        AND NOT EXISTS (
          SELECT 1 FROM room_services existing
          WHERE existing.room_id = rs.room_id
            AND existing.service_variant_id = canonical.min_id
        );
    SQL

    # 2. Delete duplicate variants
    execute <<~SQL
      DELETE FROM service_variants sv1
      USING service_variants sv2
      WHERE sv1.service_id = sv2.service_id
        AND sv1.fee = sv2.fee
        AND sv1.unit = sv2.unit
        AND sv1.is_real_time = sv2.is_real_time
        AND sv1.id > sv2.id;
    SQL

    add_index :service_variants, %i[service_id fee unit is_real_time],
              unique: true,
              name: "index_service_variants_uniqueness"
  end

  def down
    remove_index :service_variants, name: "index_service_variants_uniqueness"
  end
end
