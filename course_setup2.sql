CREATE TABLE SEMESTER (
    semester_id INT PRIMARY KEY AUTO_INCREMENT,
    semester_name VARCHAR(20) NOT NULL,     -- e.g., 'Spring 2025'
    start_date DATE,
    end_date DATE
);


CREATE TABLE OFFERING (
    offering_id INT PRIMARY KEY AUTO_INCREMENT,
    course_id INT NOT NULL,
    faculty_id INT NOT NULL,
    semester_id INT NOT NULL,
    section VARCHAR(5),                     -- e.g., 'A', 'B' (optional)
    max_capacity INT DEFAULT 60,
    
    FOREIGN KEY (course_id) REFERENCES COURSE(course_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (faculty_id) REFERENCES FACULTY(faculty_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (semester_id) REFERENCES SEMESTER(semester_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

