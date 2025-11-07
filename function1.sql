DELIMITER $$

CREATE FUNCTION total_credits(studentId INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total INT;

    SELECT SUM(c.credits) INTO total
    FROM COURSE c
    JOIN REGISTRATION r ON c.course_id = r.course_id
    WHERE r.student_id = studentId;

    RETURN IFNULL(total, 0);
END$$

DELIMITER ;
