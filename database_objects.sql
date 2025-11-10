-- Advanced Database Objects for CourseHub
USE course_registration;

-- ==================== FUNCTIONS ====================

-- Function 1: Calculate student's GPA
DELIMITER //
CREATE FUNCTION calculate_gpa(student_id_param INT)
RETURNS DECIMAL(3,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE gpa DECIMAL(3,2);
    
    SELECT AVG(
        CASE grade
            WHEN 'A+' THEN 4.0
            WHEN 'A' THEN 4.0
            WHEN 'A-' THEN 3.7
            WHEN 'B+' THEN 3.3
            WHEN 'B' THEN 3.0
            WHEN 'B-' THEN 2.7
            WHEN 'C+' THEN 2.3
            WHEN 'C' THEN 2.0
            WHEN 'C-' THEN 1.7
            WHEN 'D' THEN 1.0
            WHEN 'F' THEN 0.0
            ELSE NULL
        END
    ) INTO gpa
    FROM ENROLLMENT
    WHERE student_id = student_id_param 
    AND grade NOT IN ('IP', 'W');
    
    RETURN IFNULL(gpa, 0.0);
END//
DELIMITER ;

-- Function 2: Get course enrollment percentage
DELIMITER //
CREATE FUNCTION get_enrollment_percentage(offering_id_param INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE enrolled_count INT;
    DECLARE max_cap INT;
    DECLARE percentage DECIMAL(5,2);
    
    SELECT COUNT(*), o.max_capacity
    INTO enrolled_count, max_cap
    FROM ENROLLMENT e
    JOIN OFFERING o ON e.offering_id = o.offering_id
    WHERE e.offering_id = offering_id_param
    GROUP BY o.max_capacity;
    
    IF max_cap > 0 THEN
        SET percentage = (enrolled_count / max_cap) * 100;
    ELSE
        SET percentage = 0;
    END IF;
    
    RETURN percentage;
END//
DELIMITER ;

-- Function 3: Check if student can enroll (capacity check)
DELIMITER //
CREATE FUNCTION can_enroll(offering_id_param INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE enrolled_count INT;
    DECLARE max_cap INT;
    
    SELECT COUNT(*), o.max_capacity
    INTO enrolled_count, max_cap
    FROM ENROLLMENT e
    RIGHT JOIN OFFERING o ON e.offering_id = o.offering_id
    WHERE o.offering_id = offering_id_param
    GROUP BY o.max_capacity;
    
    RETURN enrolled_count < max_cap;
END//
DELIMITER ;

-- ==================== STORED PROCEDURES ====================

-- Procedure 1: Enroll student with validation
DELIMITER //
CREATE PROCEDURE enroll_student(
    IN p_student_id INT,
    IN p_offering_id INT,
    OUT p_status VARCHAR(100)
)
BEGIN
    DECLARE v_enrolled_count INT;
    DECLARE v_max_capacity INT;
    DECLARE v_already_enrolled INT;
    
    -- Check if already enrolled
    SELECT COUNT(*) INTO v_already_enrolled
    FROM ENROLLMENT
    WHERE student_id = p_student_id AND offering_id = p_offering_id;
    
    IF v_already_enrolled > 0 THEN
        SET p_status = 'ERROR: Already enrolled in this course';
    ELSE
        -- Check capacity
        SELECT COUNT(*), o.max_capacity
        INTO v_enrolled_count, v_max_capacity
        FROM ENROLLMENT e
        RIGHT JOIN OFFERING o ON e.offering_id = o.offering_id
        WHERE o.offering_id = p_offering_id
        GROUP BY o.max_capacity;
        
        IF v_enrolled_count >= v_max_capacity THEN
            SET p_status = 'ERROR: Course is full';
        ELSE
            -- Enroll the student
            INSERT INTO ENROLLMENT (student_id, offering_id, enrollment_date, grade)
            VALUES (p_student_id, p_offering_id, CURDATE(), 'IP');
            SET p_status = 'SUCCESS: Enrolled successfully';
        END IF;
    END IF;
END//
DELIMITER ;

-- Procedure 2: Get student transcript
DELIMITER //
CREATE PROCEDURE get_student_transcript(IN p_student_id INT)
BEGIN
    SELECT 
        c.course_id,
        c.title,
        c.credits,
        o.semester,
        o.section,
        CONCAT(f.first_name, ' ', f.last_name) as faculty_name,
        e.grade,
        CASE e.grade
            WHEN 'A+' THEN 4.0
            WHEN 'A' THEN 4.0
            WHEN 'A-' THEN 3.7
            WHEN 'B+' THEN 3.3
            WHEN 'B' THEN 3.0
            WHEN 'B-' THEN 2.7
            WHEN 'C+' THEN 2.3
            WHEN 'C' THEN 2.0
            WHEN 'C-' THEN 1.7
            WHEN 'D' THEN 1.0
            WHEN 'F' THEN 0.0
            ELSE NULL
        END as grade_points
    FROM ENROLLMENT e
    JOIN OFFERING o ON e.offering_id = o.offering_id
    JOIN COURSE c ON o.course_id = c.course_id
    JOIN FACULTY f ON o.faculty_id = f.faculty_id
    WHERE e.student_id = p_student_id
    ORDER BY o.semester DESC, c.title;
END//
DELIMITER ;

-- Procedure 3: Get course statistics for faculty
DELIMITER //
CREATE PROCEDURE get_course_statistics(IN p_offering_id INT)
BEGIN
    SELECT 
        COUNT(*) as total_students,
        SUM(CASE WHEN grade IN ('A+', 'A', 'A-') THEN 1 ELSE 0 END) as a_grades,
        SUM(CASE WHEN grade IN ('B+', 'B', 'B-') THEN 1 ELSE 0 END) as b_grades,
        SUM(CASE WHEN grade IN ('C+', 'C', 'C-') THEN 1 ELSE 0 END) as c_grades,
        SUM(CASE WHEN grade = 'D' THEN 1 ELSE 0 END) as d_grades,
        SUM(CASE WHEN grade = 'F' THEN 1 ELSE 0 END) as f_grades,
        SUM(CASE WHEN grade = 'IP' THEN 1 ELSE 0 END) as in_progress,
        AVG(CASE 
            WHEN grade = 'A+' THEN 4.0
            WHEN grade = 'A' THEN 4.0
            WHEN grade = 'A-' THEN 3.7
            WHEN grade = 'B+' THEN 3.3
            WHEN grade = 'B' THEN 3.0
            WHEN grade = 'B-' THEN 2.7
            WHEN grade = 'C+' THEN 2.3
            WHEN grade = 'C' THEN 2.0
            WHEN grade = 'C-' THEN 1.7
            WHEN grade = 'D' THEN 1.0
            WHEN grade = 'F' THEN 0.0
            ELSE NULL
        END) as average_gpa
    FROM ENROLLMENT
    WHERE offering_id = p_offering_id;
END//
DELIMITER ;

-- Procedure 4: Update student grade with validation
DELIMITER //
CREATE PROCEDURE update_student_grade(
    IN p_enrollment_id INT,
    IN p_new_grade VARCHAR(2),
    OUT p_status VARCHAR(100)
)
BEGIN
    DECLARE v_old_grade VARCHAR(2);
    
    -- Get current grade
    SELECT grade INTO v_old_grade
    FROM ENROLLMENT
    WHERE enrollment_id = p_enrollment_id;
    
    -- Validate grade
    IF p_new_grade NOT IN ('A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D', 'F', 'IP', 'W') THEN
        SET p_status = 'ERROR: Invalid grade';
    ELSE
        -- Update grade
        UPDATE ENROLLMENT
        SET grade = p_new_grade
        WHERE enrollment_id = p_enrollment_id;
        
        SET p_status = CONCAT('SUCCESS: Grade updated from ', v_old_grade, ' to ', p_new_grade);
    END IF;
END//
DELIMITER ;

-- ==================== TRIGGERS ====================

-- Trigger 1: Prevent enrollment if course is full
DELIMITER //
CREATE TRIGGER check_capacity_before_enrollment
BEFORE INSERT ON ENROLLMENT
FOR EACH ROW
BEGIN
    DECLARE v_enrolled_count INT;
    DECLARE v_max_capacity INT;
    
    SELECT COUNT(*), o.max_capacity
    INTO v_enrolled_count, v_max_capacity
    FROM ENROLLMENT e
    RIGHT JOIN OFFERING o ON e.offering_id = o.offering_id
    WHERE o.offering_id = NEW.offering_id
    GROUP BY o.max_capacity;
    
    IF v_enrolled_count >= v_max_capacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot enroll: Course is at maximum capacity';
    END IF;
END//
DELIMITER ;

-- Trigger 2: Log enrollment history
CREATE TABLE IF NOT EXISTS ENROLLMENT_HISTORY (
    history_id INT PRIMARY KEY AUTO_INCREMENT,
    enrollment_id INT,
    student_id INT,
    offering_id INT,
    action VARCHAR(20),
    old_grade VARCHAR(2),
    new_grade VARCHAR(2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_student (student_id),
    INDEX idx_offering (offering_id)
);

DELIMITER //
CREATE TRIGGER log_enrollment_changes
AFTER UPDATE ON ENROLLMENT
FOR EACH ROW
BEGIN
    IF OLD.grade != NEW.grade THEN
        INSERT INTO ENROLLMENT_HISTORY (enrollment_id, student_id, offering_id, action, old_grade, new_grade)
        VALUES (NEW.enrollment_id, NEW.student_id, NEW.offering_id, 'GRADE_UPDATE', OLD.grade, NEW.grade);
    END IF;
END//
DELIMITER ;

-- Trigger 3: Log enrollment deletions (drops)
DELIMITER //
CREATE TRIGGER log_enrollment_drops
BEFORE DELETE ON ENROLLMENT
FOR EACH ROW
BEGIN
    INSERT INTO ENROLLMENT_HISTORY (enrollment_id, student_id, offering_id, action, old_grade, new_grade)
    VALUES (OLD.enrollment_id, OLD.student_id, OLD.offering_id, 'DROPPED', OLD.grade, NULL);
END//
DELIMITER ;

-- Trigger 4: Prevent deletion of department with active students
DELIMITER //
CREATE TRIGGER prevent_department_deletion
BEFORE DELETE ON DEPARTMENT
FOR EACH ROW
BEGIN
    DECLARE v_student_count INT;
    DECLARE v_faculty_count INT;
    
    SELECT COUNT(*) INTO v_student_count
    FROM STUDENT
    WHERE dept_id = OLD.dept_id;
    
    SELECT COUNT(*) INTO v_faculty_count
    FROM FACULTY
    WHERE dept_id = OLD.dept_id;
    
    IF v_student_count > 0 OR v_faculty_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete department: Has active students or faculty';
    END IF;
END//
DELIMITER ;

-- Trigger 5: Auto-set enrollment date
DELIMITER //
CREATE TRIGGER set_enrollment_date
BEFORE INSERT ON ENROLLMENT
FOR EACH ROW
BEGIN
    IF NEW.enrollment_date IS NULL THEN
        SET NEW.enrollment_date = CURDATE();
    END IF;
    
    IF NEW.grade IS NULL THEN
        SET NEW.grade = 'IP';
    END IF;
END//
DELIMITER ;

-- ==================== VIEWS ====================

-- View 1: Student Performance Summary
CREATE OR REPLACE VIEW student_performance AS
SELECT 
    s.student_id,
    CONCAT(s.first_name, ' ', s.last_name) as student_name,
    s.email,
    d.dept_name,
    s.enrollment_year,
    COUNT(DISTINCT e.enrollment_id) as courses_taken,
    SUM(CASE WHEN e.grade NOT IN ('IP', 'W', 'F') THEN c.credits ELSE 0 END) as credits_earned,
    calculate_gpa(s.student_id) as gpa
FROM STUDENT s
LEFT JOIN ENROLLMENT e ON s.student_id = e.student_id
LEFT JOIN OFFERING o ON e.offering_id = o.offering_id
LEFT JOIN COURSE c ON o.course_id = c.course_id
LEFT JOIN DEPARTMENT d ON s.dept_id = d.dept_id
GROUP BY s.student_id, s.first_name, s.last_name, s.email, d.dept_name, s.enrollment_year;

-- View 2: Course Enrollment Summary
CREATE OR REPLACE VIEW course_enrollment_summary AS
SELECT 
    c.course_id,
    c.title,
    o.offering_id,
    o.semester,
    o.section,
    CONCAT(f.first_name, ' ', f.last_name) as faculty_name,
    d.dept_name,
    o.max_capacity,
    COUNT(e.enrollment_id) as enrolled_count,
    o.max_capacity - COUNT(e.enrollment_id) as available_seats,
    get_enrollment_percentage(o.offering_id) as enrollment_percentage
FROM OFFERING o
JOIN COURSE c ON o.course_id = c.course_id
JOIN FACULTY f ON o.faculty_id = f.faculty_id
JOIN DEPARTMENT d ON c.dept_id = d.dept_id
LEFT JOIN ENROLLMENT e ON o.offering_id = e.offering_id
GROUP BY o.offering_id, c.course_id, c.title, o.semester, o.section, 
         f.first_name, f.last_name, d.dept_name, o.max_capacity;

-- View 3: Faculty Teaching Load
CREATE OR REPLACE VIEW faculty_teaching_load AS
SELECT 
    f.faculty_id,
    CONCAT(f.first_name, ' ', f.last_name) as faculty_name,
    d.dept_name,
    COUNT(DISTINCT o.offering_id) as courses_teaching,
    COUNT(DISTINCT e.student_id) as total_students,
    SUM(c.credits) as total_credits
FROM FACULTY f
LEFT JOIN OFFERING o ON f.faculty_id = o.faculty_id
LEFT JOIN COURSE c ON o.course_id = c.course_id
LEFT JOIN ENROLLMENT e ON o.offering_id = e.offering_id
LEFT JOIN DEPARTMENT d ON f.dept_id = d.dept_id
GROUP BY f.faculty_id, f.first_name, f.last_name, d.dept_name;

-- Display created objects
SELECT 'Database objects created successfully!' as status;
SELECT 'Functions: calculate_gpa, get_enrollment_percentage, can_enroll' as functions;
SELECT 'Procedures: enroll_student, get_student_transcript, get_course_statistics, update_student_grade' as procedures;
SELECT 'Triggers: check_capacity_before_enrollment, log_enrollment_changes, log_enrollment_drops, prevent_department_deletion, set_enrollment_date' as triggers;
SELECT 'Views: student_performance, course_enrollment_summary, faculty_teaching_load' as views;
