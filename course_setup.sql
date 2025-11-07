-- 1. Create and select the database
CREATE DATABASE IF NOT EXISTS course_registration;
USE course_registration;

-- 2. Create the tables

-- STUDENT table: Stores student personal and address details
CREATE TABLE STUDENT (
    student_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    dob DATE,
    street VARCHAR(100),
    city VARCHAR(50),
    pincode CHAR(6)
);

-- PHONE table: Stores multiple phone numbers for a student
CREATE TABLE PHONE (
    student_id INT NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    PRIMARY KEY (student_id, phone_number),
    FOREIGN KEY (student_id) REFERENCES STUDENT(student_id)
);

-- FACULTY table: Stores details of academic staff
CREATE TABLE FACULTY (
    faculty_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    designation VARCHAR(50),
    department VARCHAR(50)
);

-- DEPARTMENT table: Stores details of academic departments
CREATE TABLE DEPARTMENT (
    dept_id INT PRIMARY KEY AUTO_INCREMENT,
    dept_name VARCHAR(100) UNIQUE NOT NULL,
    building VARCHAR(50)
);

-- COURSE table: Stores details of courses offered
CREATE TABLE COURSE (
    course_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    credits INT NOT NULL,
    description TEXT,
    dept_id INT,
    faculty_id INT, -- Assuming one faculty member is primarily in charge of the course
    FOREIGN KEY (dept_id) REFERENCES DEPARTMENT(dept_id),
    FOREIGN KEY (faculty_id) REFERENCES FACULTY(faculty_id)
);

-- PREREQUISITE table: Defines course dependencies (Course A requires Prereq Course B)
CREATE TABLE PREREQUISITE (
    prereq_id INT PRIMARY KEY AUTO_INCREMENT,
    course_id INT NOT NULL,
    prereq_course_id INT NOT NULL,
    UNIQUE (course_id, prereq_course_id),
    FOREIGN KEY (course_id) REFERENCES COURSE(course_id),
    FOREIGN KEY (prereq_course_id) REFERENCES COURSE(course_id)
);

-- REGISTRATION table: Links students to courses they have taken or are taking
CREATE TABLE REGISTRATION (
    reg_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    semester VARCHAR(10) NOT NULL,
    date_registered DATE NOT NULL,
    grade CHAR(2),
    UNIQUE (student_id, course_id, semester), -- A student can only register for a course once per semester
    FOREIGN KEY (student_id) REFERENCES STUDENT(student_id),
    FOREIGN KEY (course_id) REFERENCES COURSE(course_id)
);

-- TIMETABLE table: Stores scheduling information for courses
CREATE TABLE TIMETABLE (
    timetable_id INT PRIMARY KEY AUTO_INCREMENT,
    course_id INT NOT NULL,
    day VARCHAR(10) NOT NULL,
    time_slot VARCHAR(20) NOT NULL,
    room VARCHAR(20),
    UNIQUE (course_id, day, time_slot), -- A course can only be in one place at one time
    FOREIGN KEY (course_id) REFERENCES COURSE(course_id)
);

-- MENTOR table: Defines the mentor relationship between a student and a faculty member
CREATE TABLE MENTOR (
    student_id INT PRIMARY KEY, -- A student has only one mentor
    mentor_id INT NOT NULL,
    FOREIGN KEY (student_id) REFERENCES STUDENT(student_id),
    FOREIGN KEY (mentor_id) REFERENCES FACULTY(faculty_id)
);