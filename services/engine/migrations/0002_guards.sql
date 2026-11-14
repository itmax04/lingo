-- LINGO-11 F-2: rules the tables of 0001 could not express as CHECKs (review R8 of F-1a).

-- A session belongs to the account of its device.
CREATE TRIGGER sessions_account_insert BEFORE INSERT ON sessions
WHEN NEW.account_id IS NOT (SELECT account_id FROM devices WHERE id = NEW.device_id)
BEGIN
  SELECT RAISE(ABORT, 'session account differs from device account');
END;

CREATE TRIGGER sessions_account_update BEFORE UPDATE OF account_id, device_id ON sessions
WHEN NEW.account_id IS NOT (SELECT account_id FROM devices WHERE id = NEW.device_id)
BEGIN
  SELECT RAISE(ABORT, 'session account differs from device account');
END;

CREATE TRIGGER devices_account_update BEFORE UPDATE OF account_id ON devices
WHEN NEW.account_id <> OLD.account_id
BEGIN
  SELECT RAISE(ABORT, 'a device does not change its account');
END;

-- The admin is never blocked, and no statement grants or removes the admin flag (spec FR-09). The first admin is
-- inserted with the flag by /api/setup.
CREATE TRIGGER accounts_admin_insert BEFORE INSERT ON accounts
WHEN NEW.is_admin = 1 AND NEW.status <> 'active'
BEGIN
  SELECT RAISE(ABORT, 'the admin cannot be blocked');
END;

CREATE TRIGGER accounts_admin_update BEFORE UPDATE OF is_admin, status ON accounts
WHEN NEW.is_admin <> OLD.is_admin OR (NEW.is_admin = 1 AND NEW.status <> 'active')
BEGIN
  SELECT RAISE(ABORT, 'the admin flag is fixed and the admin cannot be blocked');
END;
