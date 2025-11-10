-- Drop the entire database and recreate it fresh
DROP DATABASE IF EXISTS course_registration;
CREATE DATABASE course_registration;
USE course_registration;

-- Create DEPARTMENT table
CREATE TABLE DEPARTMENT (
    dept_id INT PRIMARY KEY AUTO_INCREMENT,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    building VARCHAR(50)
);

-- Create STUDENT table
CREATE TABLE STUDENT (
    student_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    dept_id INT,
    enrollment_year INT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(64) NOT NULL,
    FOREIGN KEY (dept_id) REFERENCES DEPARTMENT(dept_id)
);

-- Create FACULTY table
CREATE TABLE FACULTY (
    faculty_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    dept_id INT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(64) NOT NULL,
    FOREIGN KEY (dept_id) REFERENCES DEPARTMENT(dept_id)
);

-- Create COURSE table
CREATE TABLE COURSE (
    course_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    credits INT NOT NULL,
    description TEXT,
    dept_id INT,
    FOREIGN KEY (dept_id) REFERENCES DEPARTMENT(dept_id)
);

-- Create OFFERING table
CREATE TABLE OFFERING (
    offering_id INT PRIMARY KEY AUTO_INCREMENT,
    course_id INT NOT NULL,
    semester VARCHAR(20) NOT NULL,
    section VARCHAR(10) NOT NULL,
    faculty_id INT NOT NULL,
    max_capacity INT DEFAULT 30,
    FOREIGN KEY (course_id) REFERENCES COURSE(course_id),
    FOREIGN KEY (faculty_id) REFERENCES FACULTY(faculty_id),
    UNIQUE KEY unique_offering (course_id, semester, section)
);

-- Create ENROLLMENT table
CREATE TABLE ENROLLMENT (
    enrollment_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT NOT NULL,
    offering_id INT NOT NULL,
    enrollment_date DATE NOT NULL,
    grade VARCHAR(2) DEFAULT 'IP',
    FOREIGN KEY (student_id) REFERENCES STUDENT(student_id) ON DELETE CASCADE,
    FOREIGN KEY (offering_id) REFERENCES OFFERING(offering_id) ON DELETE CASCADE,
    UNIQUE KEY unique_enrollment (student_id, offering_id)
);

-- Insert sample departments
INSERT INTO DEPARTMENT (dept_name, building) VALUES
('Computer Science', 'Engineering Building A'),
('Mathematics', 'Science Building B'),
('Physics', 'Science Building C'),
('Business Administration', 'Business Building'),
('English Literature', 'Arts Building');

-- Insert sample faculty (password: 'password' hashed with SHA-256)
INSERT INTO FACULTY (first_name, last_name, email, dept_id, username, password) VALUES
('John', 'Smith', 'john.smith@university.edu', 1, 'jsmith', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('Sarah', 'Johnson', 'sarah.johnson@university.edu', 1, 'sjohnson', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('Michael', 'Brown', 'michael.brown@university.edu', 2, 'mbrown', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('Emily', 'Davis', 'emily.davis@university.edu', 3, 'edavis', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8');

-- Insert sample students (password: 'password' hashed with SHA-256)
INSERT INTO STUDENT (first_name, last_name, email, dept_id, enrollment_year, username, password) VALUES
('Alice', 'Williams', 'alice.williams@student.edu', 1, 2023, 'awilliams', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('Bob', 'Martinez', 'bob.martinez@student.edu', 1, 2023, 'bmartinez', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('Carol', 'Garcia', 'carol.garcia@student.edu', 2, 2024, 'cgarcia', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8');

-- Insert sample courses
INSERT INTO COURSE (title, credits, description, dept_id) VALUES
('Introduction to Programming', 3, 'Learn the fundamentals of programming using Python', 1),
('Data Structures', 4, 'Study of fundamental data structures and algorithms', 1),
('Database Systems', 3, 'Introduction to database design and SQL', 1),
('Web Development', 3, 'Build modern web applications with HTML, CSS, and JavaScript', 1),
('Calculus I', 4, 'Differential and integral calculus', 2),
('Linear Algebra', 3, 'Matrices, vectors, and linear transformations', 2),
('Physics I', 4, 'Mechanics and thermodynamics', 3);

-- Insert sample offerings
INSERT INTO OFFERING (course_id, semester, section, faculty_id, max_capacity) VALUES
(1, 'Fall 2024', 'A', 1, 30),
(2, 'Fall 2024', 'A', 1, 25),
(3, 'Fall 2024', 'A', 2, 30),
(4, 'Spring 2025', 'A', 2, 28),
(5, 'Fall 2024', 'A', 3, 35),
(6, 'Fall 2024', 'A', 3, 30),
(7, 'Fall 2024', 'A', 4, 32);

-- Insert sample enrollments
INSERT INTO ENROLLMENT (student_id, offering_id, enrollment_date, grade) VALUES
(1, 1, '2024-08-15', 'A'),
(1, 3, '2024-08-15', 'B+'),
(2, 1, '2024-08-16', 'IP'),
(2, 2, '2024-08-16', 'IP'),
(3, 5, '2024-08-17', 'A-');
