DELIMITER $$

CREATE TRIGGER auto_set_registration_date
BEFORE INSERT ON REGISTRATION
FOR EACH ROW
BEGIN
    IF NEW.date_registered IS NULL THEN
        SET NEW.date_registered = CURDATE();
    END IF;
END$$

DELIMITER ;
