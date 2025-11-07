SET FOREIGN_KEY_CHECKS = 1;

SET SQL_SAFE_UPDATES = 1;

-- Reset course capacity
UPDATE OFFERING SET max_capacity = 50 WHERE course_id = 501;

-- Remove any temporary test registrations
DELETE FROM REGISTRATION WHERE reg_id >= 10;
