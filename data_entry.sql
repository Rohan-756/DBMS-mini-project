-- =========================================================
-- SAMPLE DATA FOR STUDENT ONLINE COURSE REGISTRATION SYSTEM
-- =========================================================

-- ========================
-- 1. DEPARTMENT
-- ========================
INSERT INTO DEPARTMENT (dept_id, dept_name, building) VALUES
(1, 'Computer Science', 'Block A'),
(2, 'Electrical Engineering', 'Block B'),
(3, 'Mechanical Engineering', 'Block C');

-- ========================
-- 2. FACULTY
-- ========================
INSERT INTO FACULTY (faculty_id, name, designation, department) VALUES
(101, 'Dr. Rithwik Adwaith', 'Professor', 'Computer Science'),
(102, 'Dr. Sneha Kumar', 'Associate Professor', 'Electrical Engineering'),
(103, 'Dr. Meera Iyer', 'Assistant Professor', 'Mechanical Engineering');

-- ========================
-- 3. COURSE
-- ========================
INSERT INTO COURSE (course_id, title, credits, description, dept_id, faculty_id) VALUES
(501, 'Database Management Systems', 4, 'Introduction to DBMS concepts', 1, 101),
(502, 'Operating Systems', 3, 'Concepts of OS and process management', 1, 101),
(503, 'Digital Electronics', 3, 'Basics of digital circuits', 2, 102),
(504, 'Thermodynamics', 4, 'Fundamentals of thermodynamics', 3, 103);

-- ========================
-- 4. STUDENT
-- ========================
INSERT INTO STUDENT (student_id, name, email, dob, street, city, pincode) VALUES
(1, 'Rohan Suresh', 'rohan@example.com', '2003-05-12', '12 MG Road', 'Bangalore', '560001'),
(2, 'Aarav Sharma', 'aarav@example.com', '2002-09-20', '45 Residency Road', 'Bangalore', '560025'),
(3, 'Isha Rao', 'isha@example.com', '2003-01-10', '78 Brigade Road', 'Bangalore', '560029');

-- ========================
-- 5. PHONE (Multivalued)
-- ========================
INSERT INTO PHONE (student_id, phone_number) VALUES
(1, '9876543210'),
(1, '9988776655'),
(2, '9123456789'),
(3, '9090909090');

-- ========================
-- 6. SEMESTER
-- ========================
INSERT INTO SEMESTER (semester_id, semester_name, start_date, end_date) VALUES
(1, 'Spring 2025', '2025-01-10', '2025-05-10'),
(2, 'Fall 2025', '2025-08-01', '2025-12-01');

-- ========================
-- 7. OFFERING (Ternary Relationship)
-- ========================
INSERT INTO OFFERING (offering_id, course_id, faculty_id, semester_id, section, max_capacity) VALUES
(1, 501, 101, 1, 'A', 50),
(2, 502, 101, 1, 'A', 40),
(3, 503, 102, 1, 'A', 35),
(4, 504, 103, 2, 'A', 45);

-- ========================
-- 8. REGISTRATION
-- ========================
INSERT INTO REGISTRATION (reg_id, student_id, course_id, semester, date_registered, grade) VALUES
(1, 1, 501, 'Spring 2025', '2025-01-15', 'A'),
(2, 1, 502, 'Spring 2025', '2025-01-16', 'B+'),
(3, 2, 501, 'Spring 2025', '2025-01-17', 'A-'),
(4, 3, 504, 'Fall 2025', '2025-08-10', 'B');

-- ========================
-- 9. TIMETABLE
-- ========================
INSERT INTO TIMETABLE (timetable_id, course_id, day, time_slot, room) VALUES
(1, 501, 'Monday', '10:00-11:00', 'A101'),
(2, 502, 'Tuesday', '09:00-10:00', 'A102'),
(3, 503, 'Wednesday', '11:00-12:00', 'B201'),
(4, 504, 'Thursday', '10:00-11:00', 'C301');

-- ========================
-- 10. MENTOR (Recursive Relationship)
-- ========================
INSERT INTO MENTOR (student_id, mentor_id) VALUES
(1, 101),  -- student Rohan mentored by Dr. Rithwik
(2, 101),
(3, 103);
