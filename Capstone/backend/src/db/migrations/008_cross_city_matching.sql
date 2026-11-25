-- 008: match compatible donors outside the request's own city
-- Previously fn_find_matching_donors filtered on d.city = request city, so a
-- request in a city without eligible compatible donors returned no matches at
-- all. Return every compatible donor, ordered same-city first, and expose
-- same_city so the UI can label the rest.

DROP FUNCTION IF EXISTS fn_find_matching_donors(TEXT, TEXT);
CREATE FUNCTION fn_find_matching_donors(
    p_blood_group TEXT,
    p_city        TEXT
)
RETURNS TABLE (
    donor_id           INT,
    name               TEXT,
    blood_group        TEXT,
    phone              TEXT,
    city               TEXT,
    last_donation_date DATE,
    total_donations    INT,
    same_city          BOOLEAN,
    is_exact_match     BOOLEAN,
    compatibility_score INT
) LANGUAGE sql STABLE AS $$
    SELECT
        d.donor_id,
        u.name,
        d.blood_group,
        u.phone,
        d.city,
        d.last_donation_date,
        d.total_donations,
        (d.city ILIKE p_city) AS same_city,
        (d.blood_group = p_blood_group) AS is_exact_match,
        CASE
            WHEN d.blood_group = p_blood_group THEN 100   -- exact ABO+Rh match
            WHEN d.blood_group = 'O-'          THEN 80    -- universal donor
            ELSE                                    60    -- ABO/Rh compatible
        END AS compatibility_score
    FROM donors d
    JOIN users u ON u.user_id = d.user_id
    JOIN blood_compatibility c
        ON c.donor_group = d.blood_group
       AND c.recipient_group = p_blood_group
    WHERE d.is_available = TRUE
      AND u.is_active = TRUE
      AND (
          d.last_donation_date IS NULL
          OR d.last_donation_date <= CURRENT_DATE - INTERVAL '90 days'
      )
    ORDER BY
        (d.city ILIKE p_city) DESC,                  -- same city first
        compatibility_score DESC,                    -- highest score first
        d.last_donation_date ASC NULLS FIRST;        -- never donated first
$$;

-- Inventory matching also reports whether the unit sits in the request city.
DROP FUNCTION IF EXISTS fn_find_matching_units(TEXT);
DROP FUNCTION IF EXISTS fn_find_matching_units(TEXT, TEXT);
CREATE FUNCTION fn_find_matching_units(
    p_blood_group TEXT,
    p_city        TEXT DEFAULT NULL
)
RETURNS TABLE (
    unit_id        INT,
    blood_group    TEXT,
    bank_id        INT,
    bank_name      TEXT,
    bank_city      TEXT,
    bank_contact   TEXT,
    collection_date DATE,
    expiry_date    DATE,
    same_city      BOOLEAN,
    is_exact_match BOOLEAN
) LANGUAGE sql STABLE AS $$
    SELECT
        i.unit_id,
        i.blood_group,
        b.bank_id,
        b.name          AS bank_name,
        b.city          AS bank_city,
        b.contact_phone AS bank_contact,
        i.collection_date,
        i.expiry_date,
        (p_city IS NOT NULL AND b.city ILIKE p_city) AS same_city,
        (i.blood_group = p_blood_group) AS is_exact_match
    FROM inventory i
    JOIN blood_banks b ON b.bank_id = i.bank_id
    JOIN blood_compatibility c
        ON c.donor_group = i.blood_group
       AND c.recipient_group = p_blood_group
    WHERE i.status = 'available'
      AND i.expiry_date >= CURRENT_DATE
    ORDER BY
        (p_city IS NOT NULL AND b.city ILIKE p_city) DESC,  -- local stock first
        (i.blood_group = p_blood_group) DESC,                -- exact match first
        i.expiry_date ASC;                                   -- nearest expiry first
$$;
