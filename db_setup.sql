-- Database Setup and Seed Data for Student Online Course Registration System
-- Creates database, tables, constraints, and inserts sample data as specified

DROP DATABASE IF EXISTS course_registration;
CREATE DATABASE course_registration;
USE course_registration;

-- TABLES
CREATE TABLE DEPARTMENT (
  dept_id INT PRIMARY KEY,
  dept_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE STUDENT (
  student_id INT PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  email VARCHAR(120) UNIQUE,
  dept_id INT,
  enrollment_year INT,
  CHECK (enrollment_year >= 2000),
  FOREIGN KEY (dept_id) REFERENCES DEPARTMENT(dept_id)
);

-- Multivalued phone numbers for students
CREATE TABLE PHONE (
  phone_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  phone_number VARCHAR(20) NOT NULL,
  UNIQUE(student_id, phone_number),
  FOREIGN KEY (student_id) REFERENCES STUDENT(student_id) ON DELETE CASCADE
);

CREATE TABLE FACULTY (
  faculty_id INT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(120) UNIQUE,
  dept_id INT,
  FOREIGN KEY (dept_id) REFERENCES DEPARTMENT(dept_id)
);

CREATE TABLE COURSE (
  course_id INT PRIMARY KEY,
  title VARCHAR(100) NOT NULL,
  credits INT NOT NULL CHECK (credits > 0),
  dept_id INT,
  FOREIGN KEY (dept_id) REFERENCES DEPARTMENT(dept_id)
);

-- Prerequisite relationships: course_id requires prereq_course_id
CREATE TABLE PREREQUISITE (
  course_id INT NOT NULL,
  prereq_course_id INT NOT NULL,
  PRIMARY KEY(course_id, prereq_course_id),
  FOREIGN KEY (course_id) REFERENCES COURSE(course_id) ON DELETE CASCADE,
  FOREIGN KEY (prereq_course_id) REFERENCES COURSE(course_id) ON DELETE CASCADE
);

CREATE TABLE SEMESTER (
  semester_id INT PRIMARY KEY,
  semester_name VARCHAR(50) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL
);

-- OFFERING: a specific section of a course in a semester taught by a faculty
CREATE TABLE OFFERING (
  offering_id INT AUTO_INCREMENT PRIMARY KEY,
  course_id INT NOT NULL,
  semester_id INT NOT NULL,
  section VARCHAR(10) NOT NULL,
  faculty_id INT NOT NULL,
  max_capacity INT NOT NULL CHECK (max_capacity > 0),
  UNIQUE(course_id, semester_id, section),
  FOREIGN KEY (course_id) REFERENCES COURSE(course_id) ON DELETE CASCADE,
  FOREIGN KEY (semester_id) REFERENCES SEMESTER(semester_id) ON DELETE CASCADE,
  FOREIGN KEY (faculty_id) REFERENCES FACULTY(faculty_id) ON DELETE CASCADE
);

-- REGISTRATION: a student registering to an offering. grade NULL => active
CREATE TABLE REGISTRATION (
  reg_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  offering_id INT NOT NULL,
  date_registered DATE,
  grade CHAR(2) NULL,
  UNIQUE(student_id, offering_id),
  FOREIGN KEY (student_id) REFERENCES STUDENT(student_id) ON DELETE CASCADE,
  FOREIGN KEY (offering_id) REFERENCES OFFERING(offering_id) ON DELETE CASCADE
);

-- TIMETABLE: schedule per offering
CREATE TABLE TIMETABLE (
  timetable_id INT AUTO_INCREMENT PRIMARY KEY,
  offering_id INT NOT NULL,
  day_of_week ENUM('Mon','Tue','Wed','Thu','Fri','Sat') NOT NULL,
  time_slot VARCHAR(20) NOT NULL, -- e.g., 09:00-10:30
  room VARCHAR(20),
  UNIQUE(offering_id, day_of_week, time_slot),
  FOREIGN KEY (offering_id) REFERENCES OFFERING(offering_id) ON DELETE CASCADE
);

-- MENTOR: faculty mentors a student
CREATE TABLE MENTOR (
  student_id INT PRIMARY KEY,
  faculty_id INT NOT NULL,
  FOREIGN KEY (student_id) REFERENCES STUDENT(student_id) ON DELETE CASCADE,
  FOREIGN KEY (faculty_id) REFERENCES FACULTY(faculty_id)
);

-- SEED DATA
INSERT INTO DEPARTMENT (dept_id, dept_name) VALUES
  (1, 'Computer Science'),
  (2, 'Electrical Engineering');

INSERT INTO STUDENT (student_id, first_name, last_name, email, dept_id, enrollment_year) VALUES
  (1, 'Rohan', 'Suresh', 'rohan.suresh@example.com', 1, 2023),
  (2, 'Aarav', 'Sharma', 'aarav.sharma@example.com', 1, 2023),
  (3, 'Isha', 'Rao', 'isha.rao@example.com', 2, 2022);

INSERT INTO PHONE (student_id, phone_number) VALUES
  (1, '+91-900000001'),
  (1, '+91-900000002'),
  (2, '+91-900000011'),
  (3, '+91-900000021');

INSERT INTO FACULTY (faculty_id, full_name, email, dept_id) VALUES
  (101, 'Dr. Rithwik Adwaith', 'rithwik.adwaith@example.com', 1),
  (102, 'Dr. Sneha Kumar', 'sneha.kumar@example.com', 1),
  (103, 'Dr. Meera Iyer', 'meera.iyer@example.com', 2);

INSERT INTO COURSE (course_id, title, credits, dept_id) VALUES
  (501, 'Intro to Programming', 3, 1),
  (502, 'Data Structures', 4, 1),
  (503, 'Database Systems', 4, 1),
  (504, 'Digital Logic', 3, 2);

-- Prerequisite: 502 requires 501
INSERT INTO PREREQUISITE (course_id, prereq_course_id) VALUES
  (502, 501);

-- Semesters
INSERT INTO SEMESTER (semester_id, semester_name, start_date, end_date) VALUES
  (1, 'Spring 2025', '2025-01-10', '2025-05-10'),
  (2, 'Fall 2025', '2025-08-01', '2025-12-01');

-- Offerings (every course offered in Spring 2025 and Fall 2025)
-- Set course 501 with low capacity = 3 in Spring 2025 to test capacity trigger
INSERT INTO OFFERING (course_id, semester_id, section, faculty_id, max_capacity) VALUES
  (501, 1, 'A', 101, 3),
  (502, 1, 'A', 102, 40),
  (503, 1, 'A', 101, 40),
  (504, 1, 'A', 103, 40),
  (501, 2, 'A', 101, 40),
  (502, 2, 'A', 102, 40),
  (503, 2, 'A', 101, 40),
  (504, 2, 'A', 103, 40);

-- Timetables: Create a clash between 501 (Spring 2025) and 503 (Spring 2025)
-- Find offering IDs first
-- (Assuming AUTO_INCREMENT in insertion order yields offering_id 1..8 as above)
INSERT INTO TIMETABLE (offering_id, day_of_week, time_slot, room) VALUES
  (1, 'Mon', '09:00-10:30', 'C101'), -- 501 Spring
  (2, 'Tue', '11:00-12:30', 'C102'),
  (3, 'Mon', '09:00-10:30', 'C103'), -- 503 Spring, clashes with 501 Spring
  (4, 'Wed', '14:00-15:30', 'E201'),
  (5, 'Mon', '10:45-12:15', 'C101'),
  (6, 'Tue', '14:00-15:30', 'C102'),
  (7, 'Thu', '09:00-10:30', 'C103'),
  (8, 'Fri', '11:00-12:30', 'E201');

-- Pre-register student 1 and 2 into 501 Spring (offering_id=1) to approach capacity
INSERT INTO REGISTRATION (student_id, offering_id, date_registered, grade) VALUES
  (1, 1, CURDATE(), NULL), -- active
  (2, 1, CURDATE(), NULL); -- active

-- Ensure at least one completed course for GPA test: student 1 completed 501 previously in Fall 2025 or earlier
-- We'll simulate a completed past offering by using Fall 2025 offering (offering_id=5) with grade 'A'
INSERT INTO REGISTRATION (student_id, offering_id, date_registered, grade) VALUES
  (1, 5, '2025-08-10', 'A');

-- Mentors
INSERT INTO MENTOR (student_id, faculty_id) VALUES
  (1, 101), (2, 102), (3, 103);

-- User accounts for login (admin, students, faculty)
CREATE TABLE IF NOT EXISTS USER_ACCOUNT (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash CHAR(64) NOT NULL, -- SHA2-256 hex
  role ENUM('student','faculty','admin') NOT NULL,
  student_id INT NULL,
  faculty_id INT NULL,
  FOREIGN KEY (student_id) REFERENCES STUDENT(student_id) ON DELETE CASCADE,
  FOREIGN KEY (faculty_id) REFERENCES FACULTY(faculty_id) ON DELETE CASCADE
);

-- Seed accounts (passwords in parentheses)
INSERT INTO USER_ACCOUNT (username, password_hash, role, student_id, faculty_id) VALUES
  ('admin', SHA2('admin123', 256), 'admin', NULL, NULL),
  ('student1', SHA2('student123', 256), 'student', 1, NULL),
  ('student2', SHA2('student123', 256), 'student', 2, NULL),
  ('student3', SHA2('student123', 256), 'student', 3, NULL),
  ('faculty101', SHA2('faculty123', 256), 'faculty', NULL, 101),
  ('faculty102', SHA2('faculty123', 256), 'faculty', NULL, 102),
  ('faculty103', SHA2('faculty123', 256), 'faculty', NULL, 103);
