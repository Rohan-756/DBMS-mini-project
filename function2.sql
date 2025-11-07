DELIMITER $$

CREATE FUNCTION faculty_for_course(courseId INT)
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
    DECLARE faculty_name VARCHAR(100);

    SELECT f.name INTO faculty_name
    FROM COURSE c
    JOIN FACULTY f ON c.faculty_id = f.faculty_id
    WHERE c.course_id = courseId;

    RETURN faculty_name;
END$$

DELIMITER ;
