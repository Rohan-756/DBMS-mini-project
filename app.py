from flask import Flask, render_template, request, redirect, url_for, session, flash
import mysql.connector
import hashlib

app = Flask(__name__)
app.secret_key = 'your-secret-key-change-in-production'
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
app.config['SESSION_COOKIE_HTTPONLY'] = True

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Rohan@2005',
    'database': 'course_registration'
}

def get_db():
    """Get database connection"""
    return mysql.connector.connect(**DB_CONFIG)

def hash_password(password):
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

# ==================== AUTHENTICATION ROUTES ====================

@app.route('/')
def index():
    """Login page"""
    if 'user_id' in session:
        if session['role'] == 'student':
            return redirect(url_for('student_dashboard'))
        elif session['role'] == 'faculty':
            return redirect(url_for('faculty_dashboard'))
    return render_template('login.html')

@app.route('/login', methods=['POST'])
def login():
    """Handle login"""
    username = request.form['username']
    password = hash_password(request.form['password'])
    
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    
    # Check student
    cursor.execute("SELECT * FROM STUDENT WHERE username = %s AND password = %s", (username, password))
    user = cursor.fetchone()
    
    if user:
        session['user_id'] = user['student_id']
        session['role'] = 'student'
        session['name'] = f"{user['first_name']} {user['last_name']}"
        cursor.close()
        conn.close()
        flash('Welcome back!', 'success')
        return redirect(url_for('student_dashboard'))
    
    # Check faculty
    cursor.execute("SELECT * FROM FACULTY WHERE username = %s AND password = %s", (username, password))
    user = cursor.fetchone()
    
    if user:
        session['user_id'] = user['faculty_id']
        session['role'] = 'faculty'
        session['name'] = f"{user['first_name']} {user['last_name']}"
        cursor.close()
        conn.close()
        flash('Welcome back!', 'success')
        return redirect(url_for('faculty_dashboard'))
    
    cursor.close()
    conn.close()
    flash('Invalid username or password', 'danger')
    return redirect(url_for('index'))

@app.route('/register')
def register():
    """Registration page"""
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM DEPARTMENT ORDER BY dept_name")
    departments = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('register.html', departments=departments)

@app.route('/register', methods=['POST'])
def register_post():
    """Handle registration"""
    role = request.form['role']
    username = request.form['username']
    password = hash_password(request.form['password'])
    first_name = request.form['first_name']
    last_name = request.form['last_name']
    email = request.form['email']
    dept_id = request.form['dept_id']
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        if role == 'student':
            enrollment_year = request.form['enrollment_year']
            cursor.execute("""
                INSERT INTO STUDENT (first_name, last_name, email, dept_id, enrollment_year, username, password)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (first_name, last_name, email, dept_id, enrollment_year, username, password))
        else:  # faculty
            cursor.execute("""
                INSERT INTO FACULTY (first_name, last_name, email, dept_id, username, password)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (first_name, last_name, email, dept_id, username, password))
        
        conn.commit()
        cursor.close()
        conn.close()
        flash('Registration successful! Please login.', 'success')
        return redirect(url_for('index'))
    except mysql.connector.Error as err:
        cursor.close()
        conn.close()
        flash(f'Registration failed: {err}', 'danger')
        return redirect(url_for('register'))

@app.route('/logout')
def logout():
    """Logout user"""
    session.clear()
    flash('You have been logged out', 'success')
    return redirect(url_for('index'))

# ==================== STUDENT ROUTES ====================

@app.route('/student/dashboard')
def student_dashboard():
    """Student dashboard"""
    if 'user_id' not in session or session['role'] != 'student':
        return redirect(url_for('index'))
    
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    
    # Get student info
    cursor.execute("""
        SELECT s.*, d.dept_name 
        FROM STUDENT s 
        JOIN DEPARTMENT d ON s.dept_id = d.dept_id 
        WHERE s.student_id = %s
    """, (session['user_id'],))
    student = cursor.fetchone()
    
    # Get enrolled courses
    cursor.execute("""
        SELECT c.course_id, c.title, c.credits, o.offering_id, o.semester, o.section, 
               CONCAT(f.first_name, ' ', f.last_name) as faculty_name,
               e.grade
        FROM ENROLLMENT e
        JOIN OFFERING o ON e.offering_id = o.offering_id
        JOIN COURSE c ON o.course_id = c.course_id
        JOIN FACULTY f ON o.faculty_id = f.faculty_id
        WHERE e.student_id = %s
        ORDER BY o.semester DESC
    """, (session['user_id'],))
    enrolled_courses = cursor.fetchall()
    
    # Get available courses
    cursor.execute("""
        SELECT c.course_id, c.title, c.credits, c.description,
               o.offering_id, o.semester, o.section, o.max_capacity,
               CONCAT(f.first_name, ' ', f.last_name) as faculty_name,
               d.dept_name,
               (SELECT COUNT(*) FROM ENROLLMENT WHERE offering_id = o.offering_id) as enrolled_count
        FROM OFFERING o
        JOIN COURSE c ON o.course_id = c.course_id
        JOIN FACULTY f ON o.faculty_id = f.faculty_id
        JOIN DEPARTMENT d ON c.dept_id = d.dept_id
        WHERE o.offering_id NOT IN (
            SELECT offering_id FROM ENROLLMENT WHERE student_id = %s
        )
        ORDER BY o.semester DESC, c.title
    """, (session['user_id'],))
    available_courses = cursor.fetchall()
    
    # Calculate total credits
    total_credits = sum(course['credits'] for course in enrolled_courses if course['grade'] != 'W')
    
    # Use function to calculate GPA
    cursor.execute("SELECT calculate_gpa(%s) as gpa", (session['user_id'],))
    gpa_result = cursor.fetchone()
    gpa = gpa_result['gpa'] if gpa_result else 0.0
    
    cursor.close()
    conn.close()
    
    return render_template('student_dashboard.html', 
                         student=student,
                         enrolled_courses=enrolled_courses,
                         available_courses=available_courses,
                         total_credits=total_credits,
                         gpa=gpa)

@app.route('/student/enroll/<int:offering_id>', methods=['POST'])
def enroll_course(offering_id):
    """Enroll in a course using stored procedure"""
    if 'user_id' not in session or session['role'] != 'student':
        return redirect(url_for('index'))
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # Use stored procedure for enrollment with validation
        status = cursor.callproc('enroll_student', [session['user_id'], offering_id, ''])
        conn.commit()
        
        # Get the output parameter
        cursor.execute("SELECT @_enroll_student_2 as status")
        result = cursor.fetchone()
        status_msg = result[0] if result else 'Unknown status'
        
        if 'SUCCESS' in status_msg:
            flash('Successfully enrolled in course!', 'success')
        else:
            flash(status_msg.replace('ERROR: ', ''), 'danger')
    except mysql.connector.Error as err:
        flash(f'Enrollment failed: {err}', 'danger')
    
    cursor.close()
    conn.close()
    return redirect(url_for('student_dashboard'))

@app.route('/student/drop/<int:offering_id>', methods=['POST'])
def drop_course(offering_id):
    """Drop a course"""
    if 'user_id' not in session or session['role'] != 'student':
        return redirect(url_for('index'))
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            DELETE FROM ENROLLMENT 
            WHERE student_id = %s AND offering_id = %s
        """, (session['user_id'], offering_id))
        conn.commit()
        flash('Successfully dropped course!', 'success')
    except mysql.connector.Error as err:
        flash(f'Drop failed: {err}', 'danger')
    
    cursor.close()
    conn.close()
    return redirect(url_for('student_dashboard'))

# ==================== FACULTY ROUTES ====================

@app.route('/faculty/dashboard')
def faculty_dashboard():
    """Faculty dashboard"""
    if 'user_id' not in session or session['role'] != 'faculty':
        return redirect(url_for('index'))
    
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    
    # Get faculty info
    cursor.execute("""
        SELECT f.*, d.dept_name 
        FROM FACULTY f 
        JOIN DEPARTMENT d ON f.dept_id = d.dept_id 
        WHERE f.faculty_id = %s
    """, (session['user_id'],))
    faculty = cursor.fetchone()
    
    # Get courses taught
    cursor.execute("""
        SELECT c.course_id, c.title, c.credits, o.offering_id, o.semester, o.section, o.max_capacity,
               (SELECT COUNT(*) FROM ENROLLMENT WHERE offering_id = o.offering_id) as enrolled_count
        FROM OFFERING o
        JOIN COURSE c ON o.course_id = c.course_id
        WHERE o.faculty_id = %s
        ORDER BY o.semester DESC
    """, (session['user_id'],))
    courses = cursor.fetchall()
    
    # Get students for each course
    for course in courses:
        cursor.execute("""
            SELECT s.student_id, CONCAT(s.first_name, ' ', s.last_name) as student_name,
                   s.email, e.grade, e.enrollment_id
            FROM ENROLLMENT e
            JOIN STUDENT s ON e.student_id = s.student_id
            WHERE e.offering_id = %s
            ORDER BY s.last_name, s.first_name
        """, (course['offering_id'],))
        course['students'] = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('faculty_dashboard.html', faculty=faculty, courses=courses)

@app.route('/faculty/courses')
def faculty_courses():
    """Faculty course management"""
    if 'user_id' not in session or session['role'] != 'faculty':
        return redirect(url_for('index'))
    
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    
    # Get faculty department
    cursor.execute("SELECT dept_id FROM FACULTY WHERE faculty_id = %s", (session['user_id'],))
    faculty = cursor.fetchone()
    
    # Get all courses in department
    cursor.execute("""
        SELECT * FROM COURSE WHERE dept_id = %s ORDER BY title
    """, (faculty['dept_id'],))
    courses = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('faculty_courses.html', courses=courses)

@app.route('/faculty/create_course', methods=['POST'])
def create_course():
    """Create a new course and offering"""
    if 'user_id' not in session or session['role'] != 'faculty':
        return redirect(url_for('index'))
    
    title = request.form['title']
    credits = request.form['credits']
    description = request.form.get('description', '')
    semester = request.form['semester']
    section = request.form['section']
    max_capacity = request.form['max_capacity']
    
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    
    # Get faculty department
    cursor.execute("SELECT dept_id FROM FACULTY WHERE faculty_id = %s", (session['user_id'],))
    faculty = cursor.fetchone()
    
    try:
        # Create course
        cursor.execute("""
            INSERT INTO COURSE (title, credits, description, dept_id)
            VALUES (%s, %s, %s, %s)
        """, (title, credits, description, faculty['dept_id']))
        course_id = cursor.lastrowid
        
        # Create offering
        cursor.execute("""
            INSERT INTO OFFERING (course_id, semester, section, faculty_id, max_capacity)
            VALUES (%s, %s, %s, %s, %s)
        """, (course_id, semester, section, session['user_id'], max_capacity))
        
        conn.commit()
        flash('Course created successfully!', 'success')
    except mysql.connector.Error as err:
        flash(f'Failed to create course: {err}', 'danger')
    
    cursor.close()
    conn.close()
    return redirect(url_for('faculty_courses'))

@app.route('/faculty/update_grade/<int:enrollment_id>', methods=['POST'])
def update_grade(enrollment_id):
    """Update student grade using stored procedure"""
    if 'user_id' not in session or session['role'] != 'faculty':
        return redirect(url_for('index'))
    
    grade = request.form['grade']
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # Use stored procedure for grade update with validation
        cursor.callproc('update_student_grade', [enrollment_id, grade, ''])
        conn.commit()
        
        # Get the output parameter
        cursor.execute("SELECT @_update_student_grade_2 as status")
        result = cursor.fetchone()
        status_msg = result[0] if result else 'Unknown status'
        
        if 'SUCCESS' in status_msg:
            flash('Grade updated successfully!', 'success')
        else:
            flash(status_msg.replace('ERROR: ', ''), 'danger')
    except mysql.connector.Error as err:
        flash(f'Failed to update grade: {err}', 'danger')
    
    cursor.close()
    conn.close()
    return redirect(url_for('faculty_dashboard'))

if __name__ == '__main__':
    app.run(debug=True)
