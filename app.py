import mysql.connector
from flask import Flask, render_template, request, redirect, url_for, session, flash

# --- 1. Database Configuration ---
# NOTE: Using the credentials you provided in your last turn.
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Rohan@2005',
    'database': 'course_registration'
}

app = Flask(__name__)
# Replace with a strong, secret key
app.secret_key = 'super_secret_key_for_session' 

# --- 2. Database Helper Functions ---
def get_db_connection():
    """Establishes a connection to the database."""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except mysql.connector.Error as err:
        # Print error details to console for debugging
        print(f"Database connection error: {err}") 
        return None

def fetch_data(query, params=None):
    """Executes a SELECT query and returns the results as a list of dictionaries."""
    conn = get_db_connection()
    if not conn:
        return []
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(query, params)
        data = cursor.fetchall()
        return data
    except mysql.connector.Error as err:
        print(f"Error fetching data: {err}")
        return []
    finally:
        cursor.close()
        conn.close()

def execute_dml(query, params=None):
    """Executes DML (INSERT/UPDATE/DELETE) and returns a success/error message."""
    conn = get_db_connection()
    if not conn:
        return "Database connection failed."
    cursor = conn.cursor()
    try:
        cursor.execute(query, params)
        conn.commit()
        return "Success"
    except mysql.connector.Error as err:
        conn.rollback()
        # Specific check for your capacity trigger (SQLSTATE '45000')
        if 'Course is already full' in str(err):
            return str(err).split(": ", 1)[-1] # Return the message TEXT
        
        print(f"Database transaction error: {err}")
        return f"Database Error: {err.msg}"
    finally:
        cursor.close()
        conn.close()

# --- 3. Flask Routes ---

@app.route('/', methods=['GET', 'POST'])
def index():
    """Simulated login/user selection page. (FIXED REDIRECT HERE)"""
    # Data from your data_entry.sql
    students = fetch_data("SELECT student_id, name FROM STUDENT;")
    faculty = fetch_data("SELECT faculty_id, name FROM FACULTY;")
    
    if request.method == 'POST':
        role = request.form.get('role')
        user_id = request.form.get('user_id')
        
        if not user_id:
             flash('Please select a user ID.', 'danger')
             return redirect(url_for('index'))

        if role == 'student':
            session['user_id'] = int(user_id)
            session['role'] = 'student'
            return redirect(url_for('student_dashboard'))
            
        elif role == 'faculty':
            session['user_id'] = int(user_id)
            session['role'] = 'faculty'
            # --- CORRECTED REDIRECT TO FACULTY DASHBOARD ---
            return redirect(url_for('faculty_dashboard'))

    return render_template('index.html', students=students, faculty=faculty)

@app.route('/logout')
def logout():
    """Clears the session."""
    session.pop('user_id', None)
    session.pop('role', None)
    return redirect(url_for('index'))

@app.route('/student/dashboard')
def student_dashboard():
    """Student Dashboard: View registered courses and available courses."""
    if session.get('role') != 'student':
        flash('Please log in as a student.', 'danger')
        return redirect(url_for('index'))

    student_id = session['user_id']
    
    # Get total credits using your stored function (function1.sql)
    credits_data = fetch_data(f"SELECT total_credits({student_id}) AS total_credits;")
    total_credits = credits_data[0]['total_credits'] if credits_data else 0

    # 1. Registered Courses
    registered_courses_query = """
    SELECT 
        R.reg_id, C.title, C.credits, R.semester, R.grade
    FROM REGISTRATION R
    JOIN COURSE C ON R.course_id = C.course_id
    WHERE R.student_id = %s;
    """
    registered_courses = fetch_data(registered_courses_query, (student_id,))

    # 2. Available Courses (Not currently registered)
    available_courses_query = """
    SELECT 
        C.course_id, C.title, C.credits, F.name AS faculty_name, S.semester_name, O.max_capacity
    FROM COURSE C
    JOIN OFFERING O ON C.course_id = O.course_id
    JOIN FACULTY F ON O.faculty_id = F.faculty_id
    JOIN SEMESTER S ON O.semester_id = S.semester_id
    WHERE C.course_id NOT IN (
        SELECT course_id FROM REGISTRATION WHERE student_id = %s
    )
    ORDER BY S.semester_name, C.title;
    """
    available_courses = fetch_data(available_courses_query, (student_id,))

    # Get student name
    student_name = fetch_data("SELECT name FROM STUDENT WHERE student_id = %s", (student_id,))
    student_name = student_name[0]['name'] if student_name else 'Unknown Student'


    return render_template(
        'student_dashboard.html', 
        name=student_name,
        total_credits=total_credits,
        registered_courses=registered_courses,
        available_courses=available_courses
    )

@app.route('/register/<int:course_id>', methods=['POST'])
def register_course(course_id):
    """Handles course registration (demonstrates trigger1.sql)."""
    if session.get('role') != 'student':
        flash('Unauthorized action.', 'danger')
        return redirect(url_for('index'))
    
    student_id = session['user_id']
    
    # 1. Find the relevant offering/semester 
    offering_data = fetch_data("""
    SELECT S.semester_name 
    FROM OFFERING O 
    JOIN SEMESTER S ON O.semester_id = S.semester_id 
    WHERE O.course_id = %s LIMIT 1
    """, (course_id,))

    if not offering_data:
        flash('Error: No active offering found for this course.', 'danger')
        return redirect(url_for('student_dashboard'))
        
    semester = offering_data[0]['semester_name']
    
    # 2. Attempt the INSERT (Trigger check_capacity_before_registration will fire)
    registration_query = """
    INSERT INTO REGISTRATION (student_id, course_id, semester)
    VALUES (%s, %s, %s);
    """
    
    result = execute_dml(registration_query, (student_id, course_id, semester))
    
    if result == "Success":
        flash(f'Successfully registered for Course ID {course_id}. Date set by trigger.', 'success')
    elif 'Course is already full' in result:
        # Catches the custom error message from the trigger!
        flash(f'Registration failed: {result}', 'danger')
    else:
        flash(f'Registration failed due to a database error: {result}', 'danger')

    return redirect(url_for('student_dashboard'))


@app.route('/faculty/dashboard')
def faculty_dashboard():
    """Faculty Dashboard: View courses taught and enrolled students."""
    if session.get('role') != 'faculty':
        flash('Please log in as faculty.', 'danger')
        return redirect(url_for('index'))

    faculty_id = session['user_id']
    
    # Get faculty name
    faculty_name = fetch_data("SELECT name FROM FACULTY WHERE faculty_id = %s", (faculty_id,))
    faculty_name = faculty_name[0]['name'] if faculty_name else 'Unknown Faculty'

    # Query to fetch all courses offered by the faculty and their students
    enrolled_students_query = """
    SELECT
        C.title AS course_title,
        O.section,
        R.reg_id,
        S.student_id,
        S.name AS student_name,
        R.semester,
        R.grade
    FROM OFFERING O
    JOIN COURSE C ON O.course_id = C.course_id
    LEFT JOIN REGISTRATION R ON C.course_id = R.course_id 
    LEFT JOIN STUDENT S ON R.student_id = S.student_id
    WHERE O.faculty_id = %s
    ORDER BY C.title, S.name;
    """
    all_enrollments = fetch_data(enrolled_students_query, (faculty_id,))
    
    # Group results by course title for easier display in the template
    courses_data = {}
    for row in all_enrollments:
        key = (row['course_title'], row['section'], row['semester'])
        if key not in courses_data:
            courses_data[key] = []
        
        # Only add student if they are actually registered (R.reg_id is not NULL)
        if row['reg_id']:
            courses_data[key].append({
                'reg_id': row['reg_id'],
                'student_id': row['student_id'],
                'student_name': row['student_name'],
                'grade': row['grade']
            })

    return render_template(
        'faculty_dashboard.html', 
        name=faculty_name,
        courses_data=courses_data
    )

@app.route('/faculty/update_grade', methods=['POST'])
def update_grade():
    """Handles grade update (Faculty functionality)."""
    if session.get('role') != 'faculty':
        flash('Unauthorized action.', 'danger')
        return redirect(url_for('index'))
    
    reg_id = request.form.get('reg_id')
    new_grade = request.form.get('grade').strip()
    
    if not reg_id or not new_grade:
        flash('Error: Missing registration ID or grade.', 'danger')
        return redirect(url_for('faculty_dashboard'))
    
    # Execute the UPDATE DML
    update_query = "UPDATE REGISTRATION SET grade = %s WHERE reg_id = %s;"
    result = execute_dml(update_query, (new_grade, reg_id))
    
    if result == "Success":
        flash(f'Grade successfully updated to {new_grade} for registration ID {reg_id}.', 'success')
    else:
        flash(f'Grade update failed due to a database error: {result}', 'danger')

    return redirect(url_for('faculty_dashboard'))

if __name__ == '__main__':
    app.run(debug=True)