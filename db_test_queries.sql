-- Sanity test queries
USE course_registration;

SELECT * FROM VIEW_COURSE_ENROLLMENT_SUMMARY;
SELECT * FROM VIEW_STUDENT_GPA;

-- Check triggers: attempt to register third student to full course etc. (run via app)
