-- DBMS Objects: Stored Functions, Triggers, and Views
USE course_registration;

DELIMITER //

-- Function: total_credits(studentId)
DROP FUNCTION IF EXISTS total_credits //
CREATE FUNCTION total_credits(studentId INT)
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE total INT;
  SELECT COALESCE(SUM(c.credits), 0) INTO total
  FROM REGISTRATION r
  JOIN OFFERING o ON r.offering_id = o.offering_id
  JOIN COURSE c ON o.course_id = c.course_id
  WHERE r.student_id = studentId;
  RETURN total;
END //

-- Function: check_prerequisites(student_id_in, course_id_to_register)
DROP FUNCTION IF EXISTS check_prerequisites //
CREATE FUNCTION check_prerequisites(student_id_in INT, course_id_to_register INT)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
  -- Returns TRUE if the student has successfully completed all required prerequisites
  -- (grade not in ('F','W') and grade is NOT NULL)
  DECLARE unmet INT;
  SELECT COUNT(*) INTO unmet
  FROM PREREQUISITE p
  LEFT JOIN OFFERING oreq ON oreq.course_id = p.prereq_course_id
  LEFT JOIN REGISTRATION r ON r.offering_id = oreq.offering_id AND r.student_id = student_id_in
  WHERE p.course_id = course_id_to_register
    AND NOT EXISTS (
      SELECT 1 FROM REGISTRATION r2
      JOIN OFFERING o2 ON r2.offering_id = o2.offering_id
      WHERE r2.student_id = student_id_in
        AND o2.course_id = p.prereq_course_id
        AND r2.grade IS NOT NULL
        AND r2.grade NOT IN ('F','W')
    );
  RETURN (unmet = 0);
END //

-- Trigger: auto_set_registration_date
DROP TRIGGER IF EXISTS auto_set_registration_date //
CREATE TRIGGER auto_set_registration_date
BEFORE INSERT ON REGISTRATION
FOR EACH ROW
BEGIN
  IF NEW.date_registered IS NULL THEN
    SET NEW.date_registered = CURDATE();
  END IF;
END //

-- Trigger: check_capacity_before_registration
DROP TRIGGER IF EXISTS check_capacity_before_registration //
CREATE TRIGGER check_capacity_before_registration
BEFORE INSERT ON REGISTRATION
FOR EACH ROW
BEGIN
  DECLARE maxcap INT;
  DECLARE enrolled INT;
  SELECT max_capacity INTO maxcap FROM OFFERING WHERE offering_id = NEW.offering_id;
  SELECT COUNT(*) INTO enrolled FROM REGISTRATION WHERE offering_id = NEW.offering_id AND grade IS NULL;
  IF enrolled >= maxcap THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course is already full. Registration not allowed.';
  END IF;
END //

-- Trigger: check_time_conflict_before_registration
DROP TRIGGER IF EXISTS check_time_conflict_before_registration //
CREATE TRIGGER check_time_conflict_before_registration
BEFORE INSERT ON REGISTRATION
FOR EACH ROW
BEGIN
  DECLARE conflict_count INT;
  SELECT COUNT(*) INTO conflict_count
  FROM TIMETABLE t_new
  JOIN OFFERING o_new ON o_new.offering_id = NEW.offering_id AND t_new.offering_id = o_new.offering_id
  JOIN REGISTRATION r ON r.student_id = NEW.student_id AND r.grade IS NULL
  JOIN OFFERING o ON o.offering_id = r.offering_id
  JOIN TIMETABLE t ON t.offering_id = o.offering_id
  WHERE t_new.day_of_week = t.day_of_week AND t_new.time_slot = t.time_slot;
  IF conflict_count > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Time conflict detected! The new course schedule clashes with an already registered course.';
  END IF;
END //

DELIMITER ;

-- Views

-- View 1: VIEW_COURSE_ENROLLMENT_SUMMARY
DROP VIEW IF EXISTS VIEW_COURSE_ENROLLMENT_SUMMARY;
CREATE VIEW VIEW_COURSE_ENROLLMENT_SUMMARY AS
SELECT
  c.title,
  s.semester_name,
  o.section,
  o.max_capacity,
  COUNT(CASE WHEN r.grade IS NULL THEN r.reg_id END) AS current_enrollment,
  (o.max_capacity - COUNT(CASE WHEN r.grade IS NULL THEN r.reg_id END)) AS seats_remaining
FROM OFFERING o
JOIN COURSE c ON c.course_id = o.course_id
JOIN SEMESTER s ON s.semester_id = o.semester_id
LEFT JOIN REGISTRATION r ON r.offering_id = o.offering_id
GROUP BY o.offering_id;

-- View 2: VIEW_STUDENT_GPA
DROP VIEW IF EXISTS VIEW_STUDENT_GPA;
CREATE VIEW VIEW_STUDENT_GPA AS
SELECT
  st.student_id,
  CONCAT(st.first_name, ' ', st.last_name) AS student_name,
  ROUND(
    CASE WHEN SUM(cr.credits) = 0 THEN NULL ELSE SUM(cr.credits * gp.points) / SUM(cr.credits) END
  , 2) AS gpa
FROM STUDENT st
JOIN REGISTRATION r ON r.student_id = st.student_id
JOIN OFFERING o ON o.offering_id = r.offering_id
JOIN COURSE cr ON cr.course_id = o.course_id
JOIN (
  SELECT 'A' AS grade, 4.0 AS points UNION ALL
  SELECT 'B', 3.0 UNION ALL
  SELECT 'C', 2.0 UNION ALL
  SELECT 'D', 1.0
) gp ON gp.grade = r.grade
WHERE r.grade IS NOT NULL AND r.grade NOT IN ('W')
GROUP BY st.student_id;
