DELIMITER $$

CREATE TRIGGER check_capacity_before_registration
BEFORE INSERT ON REGISTRATION
FOR EACH ROW
BEGIN
    DECLARE current_enrollment INT;
    DECLARE max_cap INT;

    SELECT COUNT(*) INTO current_enrollment
    FROM REGISTRATION r
    JOIN OFFERING o ON r.course_id = o.course_id
    WHERE r.course_id = NEW.course_id AND o.offering_id = o.offering_id;

    SELECT max_capacity INTO max_cap
    FROM OFFERING
    WHERE course_id = NEW.course_id
    LIMIT 1;

    IF current_enrollment >= max_cap THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Course is already full. Registration not allowed.';
    END IF;
END$$

DELIMITER ;
