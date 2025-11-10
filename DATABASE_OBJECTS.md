# Database Objects Documentation

This document explains all the advanced database objects (functions, procedures, triggers, and views) used in the CourseHub application.

## 📊 Functions

### 1. `calculate_gpa(student_id_param INT)`
**Purpose**: Calculates a student's GPA based on completed courses.

**Returns**: `DECIMAL(3,2)` - GPA value from 0.00 to 4.00

**Usage in App**: Used in student dashboard to display current GPA

**Grade Point Scale**:
- A+, A = 4.0
- A- = 3.7
- B+ = 3.3
- B = 3.0
- B- = 2.7
- C+ = 2.3
- C = 2.0
- C- = 1.7
- D = 1.0
- F = 0.0
- IP (In Progress) and W (Withdrawn) are excluded

**Example**:
```sql
SELECT calculate_gpa(1) as student_gpa;
```

---

### 2. `get_enrollment_percentage(offering_id_param INT)`
**Purpose**: Calculates what percentage of a course's capacity is filled.

**Returns**: `DECIMAL(5,2)` - Percentage from 0.00 to 100.00

**Usage**: Can be used to identify popular courses or courses at risk of cancellation

**Example**:
```sql
SELECT title, get_enrollment_percentage(offering_id) as fill_rate
FROM OFFERING o
JOIN COURSE c ON o.course_id = c.course_id;
```

---

### 3. `can_enroll(offering_id_param INT)`
**Purpose**: Checks if a course has available seats.

**Returns**: `BOOLEAN` - TRUE if seats available, FALSE if full

**Usage**: Quick capacity check before enrollment

**Example**:
```sql
SELECT title, can_enroll(offering_id) as has_space
FROM OFFERING o
JOIN COURSE c ON o.course_id = c.course_id;
```

---

## 🔧 Stored Procedures

### 1. `enroll_student(p_student_id, p_offering_id, OUT p_status)`
**Purpose**: Enrolls a student in a course with built-in validation.

**Parameters**:
- `IN p_student_id` - Student ID
- `IN p_offering_id` - Course offering ID
- `OUT p_status` - Status message (SUCCESS or ERROR)

**Validations**:
- Checks if student is already enrolled
- Checks if course is at capacity
- Prevents duplicate enrollments

**Usage in App**: Used in the enrollment route to ensure safe course registration

**Example**:
```sql
CALL enroll_student(1, 5, @status);
SELECT @status;
```

---

### 2. `get_student_transcript(p_student_id INT)`
**Purpose**: Retrieves complete academic transcript for a student.

**Parameters**:
- `IN p_student_id` - Student ID

**Returns**: Result set with:
- Course ID, title, credits
- Semester, section
- Faculty name
- Grade and grade points

**Usage**: Generate official transcripts or academic reports

**Example**:
```sql
CALL get_student_transcript(1);
```

---

### 3. `get_course_statistics(p_offering_id INT)`
**Purpose**: Provides detailed grade distribution statistics for a course.

**Parameters**:
- `IN p_offering_id` - Course offering ID

**Returns**: Result set with:
- Total students
- Count of A, B, C, D, F grades
- In-progress count
- Average GPA

**Usage**: Faculty can analyze course performance and grade distribution

**Example**:
```sql
CALL get_course_statistics(1);
```

---

### 4. `update_student_grade(p_enrollment_id, p_new_grade, OUT p_status)`
**Purpose**: Updates a student's grade with validation and logging.

**Parameters**:
- `IN p_enrollment_id` - Enrollment record ID
- `IN p_new_grade` - New grade value
- `OUT p_status` - Status message

**Validations**:
- Validates grade is in allowed list
- Logs the change in ENROLLMENT_HISTORY

**Usage in App**: Used when faculty updates grades

**Example**:
```sql
CALL update_student_grade(1, 'A', @status);
SELECT @status;
```

---

## ⚡ Triggers

### 1. `check_capacity_before_enrollment`
**Type**: BEFORE INSERT on ENROLLMENT

**Purpose**: Prevents enrollment if course is at maximum capacity.

**Behavior**: Raises error if trying to enroll in a full course

**Impact**: Ensures data integrity and prevents over-enrollment

---

### 2. `log_enrollment_changes`
**Type**: AFTER UPDATE on ENROLLMENT

**Purpose**: Logs all grade changes to ENROLLMENT_HISTORY table.

**Behavior**: 
- Tracks old grade → new grade
- Records timestamp
- Links to student and offering

**Impact**: Creates audit trail for grade changes

---

### 3. `log_enrollment_drops`
**Type**: BEFORE DELETE on ENROLLMENT

**Purpose**: Logs when students drop courses.

**Behavior**: Records the drop action with the grade at time of drop

**Impact**: Maintains historical record of course drops

---

### 4. `prevent_department_deletion`
**Type**: BEFORE DELETE on DEPARTMENT

**Purpose**: Prevents deletion of departments with active students or faculty.

**Behavior**: Raises error if department has members

**Impact**: Protects referential integrity

---

### 5. `set_enrollment_date`
**Type**: BEFORE INSERT on ENROLLMENT

**Purpose**: Auto-sets enrollment date and default grade.

**Behavior**:
- Sets enrollment_date to current date if NULL
- Sets grade to 'IP' (In Progress) if NULL

**Impact**: Ensures consistent data entry

---

## 📋 Views

### 1. `student_performance`
**Purpose**: Comprehensive view of all students' academic performance.

**Columns**:
- student_id, student_name, email
- dept_name, enrollment_year
- courses_taken, credits_earned
- gpa (calculated using function)

**Usage**: Quick lookup of student academic standing

**Example**:
```sql
SELECT * FROM student_performance WHERE gpa >= 3.5;
```

---

### 2. `course_enrollment_summary`
**Purpose**: Overview of all course offerings with enrollment data.

**Columns**:
- course_id, title, offering_id
- semester, section, faculty_name
- dept_name, max_capacity
- enrolled_count, available_seats
- enrollment_percentage

**Usage**: Monitor course popularity and capacity

**Example**:
```sql
SELECT * FROM course_enrollment_summary 
WHERE enrollment_percentage > 90;
```

---

### 3. `faculty_teaching_load`
**Purpose**: Summary of each faculty member's teaching responsibilities.

**Columns**:
- faculty_id, faculty_name, dept_name
- courses_teaching
- total_students
- total_credits

**Usage**: Analyze faculty workload distribution

**Example**:
```sql
SELECT * FROM faculty_teaching_load 
ORDER BY total_students DESC;
```

---

## 🗄️ Additional Tables

### `ENROLLMENT_HISTORY`
**Purpose**: Audit log for all enrollment changes.

**Columns**:
- history_id (PK)
- enrollment_id
- student_id, offering_id
- action (GRADE_UPDATE or DROPPED)
- old_grade, new_grade
- changed_at (timestamp)

**Populated By**: Triggers `log_enrollment_changes` and `log_enrollment_drops`

**Usage**: Track grade history and course drop patterns

**Example**:
```sql
SELECT * FROM ENROLLMENT_HISTORY 
WHERE student_id = 1 
ORDER BY changed_at DESC;
```

---

## 🚀 How to Install

Run the database objects script:

```bash
mysql -u root -p course_registration < database_objects.sql
```

Or in MySQL:
```sql
USE course_registration;
source d:\DBMS-mini-project\database_objects.sql
```

---

## ✅ Verification

Check that all objects were created:

```sql
-- Check functions
SHOW FUNCTION STATUS WHERE Db = 'course_registration';

-- Check procedures
SHOW PROCEDURE STATUS WHERE Db = 'course_registration';

-- Check triggers
SHOW TRIGGERS FROM course_registration;

-- Check views
SHOW FULL TABLES IN course_registration WHERE TABLE_TYPE = 'VIEW';
```

---

## 📝 Notes

- All functions are marked as `DETERMINISTIC` and `READS SQL DATA` for optimization
- Stored procedures include error handling and validation
- Triggers ensure data integrity automatically
- Views provide convenient access to complex queries
- The ENROLLMENT_HISTORY table grows over time - consider archiving old records periodically

---

**Last Updated**: November 2025
