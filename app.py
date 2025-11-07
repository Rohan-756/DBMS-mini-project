import mysql.connector
from flask import Flask, render_template, request, redirect, url_for, session, flash

# Database configuration per specification
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Rohan@2005',
    'database': 'course_registration'
}

ADMIN_ID = 999

app = Flask(__name__)
app.secret_key = 'replace_with_a_strong_secret_key'

# ---- DB helpers ----
def get_conn():
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except mysql.connector.Error as err:
        print(f"DB connect error: {err}")
        return None

def fetch_all(sql, params=None):
    conn = get_conn()
    if not conn:
        return []
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute(sql, params)
        return cur.fetchall()
    except mysql.connector.Error as err:
        print(f"Fetch error: {err}")
        return []
    finally:
        cur.close()
        conn.close()

def fetch_one(sql, params=None):
    rows = fetch_all(sql, params)
    return rows[0] if rows else None

def execute_dml(sql, params=None):
    conn = get_conn()
    if not conn:
        return "Database connection failed."
    cur = conn.cursor()
    try:
        cur.execute(sql, params)
        conn.commit()
        return "Success"
    except mysql.connector.Error as err:
        conn.rollback()
        msg = str(err)
        # Propagate trigger custom messages
        if 'Course is already full' in msg:
            return 'Course is already full. Registration not allowed.'
        if 'Time conflict detected!' in msg:
            return 'Time conflict detected! The new course schedule clashes with an already registered course.'
        return f"Database Error: {getattr(err, 'msg', msg)}"
    finally:
        cur.close()
        conn.close()

# ---- Auth / Index ----
@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        username = (request.form.get('username') or '').strip()
        password = request.form.get('password') or ''
        if not username or not password:
            flash('Enter username and password.', 'danger')
            return redirect(url_for('index'))
        row = fetch_one(
            """
            SELECT username, role, student_id, faculty_id
            FROM USER_ACCOUNT
            WHERE username=%s AND password_hash = SHA2(%s,256)
            """,
            (username, password)
        )
        if not row:
            flash('Invalid credentials.', 'danger')
            return redirect(url_for('index'))
        role = row['role']
        if role == 'admin':
            session['role'] = 'admin'
            session['user_id'] = ADMIN_ID
            return redirect(url_for('admin_dashboard'))
        if role == 'student' and row['student_id']:
            session['role'] = 'student'
            session['user_id'] = int(row['student_id'])
            return redirect(url_for('student_dashboard'))
        if role == 'faculty' and row['faculty_id']:
            session['role'] = 'faculty'
            session['user_id'] = int(row['faculty_id'])
            return redirect(url_for('faculty_dashboard'))

# ---- Faculty Course Management ----
def _faculty_dept_id(faculty_id:int):
    row = fetch_one("SELECT dept_id FROM FACULTY WHERE faculty_id=%s", (faculty_id,))
    return row['dept_id'] if row else None

@app.route('/faculty/courses')
def faculty_courses():
    if session.get('role') != 'faculty':
        flash('Please log in as faculty.', 'danger')
        return redirect(url_for('index'))
    fid = session.get('user_id')
    dept_id = _faculty_dept_id(fid)
    if not dept_id:
        flash('Department not found for faculty.', 'danger')
        return redirect(url_for('faculty_dashboard'))
    courses = fetch_all("SELECT course_id, title, credits FROM COURSE WHERE dept_id=%s ORDER BY course_id", (dept_id,))
    return render_template('faculty_courses.html', courses=courses)

@app.route('/faculty/course/create', methods=['POST'])
def faculty_course_create():
    if session.get('role') != 'faculty':
        flash('Please log in as faculty.', 'danger')
        return redirect(url_for('index'))
    title = (request.form.get('title') or '').strip()
    credits = request.form.get('credits')
    if not title or not credits:
        flash('Provide title and credits.', 'danger')
        return redirect(url_for('faculty_courses'))
    fid = session.get('user_id')
    dept_id = _faculty_dept_id(fid)
    err = execute_dml("INSERT INTO COURSE (title, credits, dept_id) VALUES (%s,%s,%s)", (title, int(credits), int(dept_id)))
    if err:
        flash(err, 'danger')
    else:
        flash('Course created.', 'success')
    return redirect(url_for('faculty_courses'))

@app.route('/faculty/course/delete/<int:course_id>', methods=['POST'])
def faculty_course_delete(course_id:int):
    if session.get('role') != 'faculty':
        flash('Please log in as faculty.', 'danger')
        return redirect(url_for('index'))
    # Prevent deletion if offerings exist
    row = fetch_one("SELECT COUNT(*) AS c FROM OFFERING WHERE course_id=%s", (course_id,))
    if row and row['c'] > 0:
        flash('Cannot delete: offerings exist for this course.', 'danger')
        return redirect(url_for('faculty_courses'))
    # Safe to delete prerequisites then course
    err = execute_dml("DELETE FROM PREREQUISITE WHERE course_id=%s OR prereq_course_id=%s", (course_id, course_id))
    if err:
        flash(err, 'danger')
        return redirect(url_for('faculty_courses'))
    err = execute_dml("DELETE FROM COURSE WHERE course_id=%s", (course_id,))
    if err:
        flash(err, 'danger')
    else:
        flash('Course removed.', 'success')
    return redirect(url_for('faculty_courses'))

@app.route('/faculty/course/<int:course_id>/prereqs')
def faculty_course_prereqs(course_id:int):
    if session.get('role') != 'faculty':
        flash('Please log in as faculty.', 'danger')
        return redirect(url_for('index'))
    # Fetch course and its prereqs
    course = fetch_one("SELECT course_id, title FROM COURSE WHERE course_id=%s", (course_id,))
    if not course:
        flash('Course not found.', 'danger')
        return redirect(url_for('faculty_courses'))
    current = fetch_all(
        """
        SELECT p.prereq_course_id AS course_id, c.title
        FROM PREREQUISITE p JOIN COURSE c ON c.course_id = p.prereq_course_id
        WHERE p.course_id=%s ORDER BY c.title
        """, (course_id,)
    )
    # candidates: same department courses excluding itself and already chosen
    fid = session.get('user_id')
    dept_id = _faculty_dept_id(fid)
    cand = fetch_all(
        """
        SELECT course_id, title FROM COURSE
        WHERE dept_id=%s AND course_id<>%s
          AND course_id NOT IN (SELECT prereq_course_id FROM PREREQUISITE WHERE course_id=%s)
        ORDER BY title
        """, (dept_id, course_id, course_id)
    )
    return render_template('faculty_prereqs.html', course=course, current=current, candidates=cand)

@app.route('/faculty/course/<int:course_id>/prereqs/add', methods=['POST'])
def faculty_course_prereq_add(course_id:int):
    if session.get('role') != 'faculty':
        flash('Please log in as faculty.', 'danger')
        return redirect(url_for('index'))
    prereq_id = request.form.get('prereq_course_id')
    if not prereq_id:
        flash('Select a prerequisite course.', 'danger')
        return redirect(url_for('faculty_course_prereqs', course_id=course_id))
    err = execute_dml("INSERT INTO PREREQUISITE (course_id, prereq_course_id) VALUES (%s,%s)", (course_id, int(prereq_id)))
    if err:
        flash(err, 'danger')
    else:
        flash('Prerequisite added.', 'success')
    return redirect(url_for('faculty_course_prereqs', course_id=course_id))

@app.route('/faculty/course/<int:course_id>/prereqs/remove', methods=['POST'])
def faculty_course_prereq_remove(course_id:int):
    if session.get('role') != 'faculty':
        flash('Please log in as faculty.', 'danger')
        return redirect(url_for('index'))
    prereq_id = request.form.get('prereq_course_id')
    if not prereq_id:
        flash('Select a prerequisite to remove.', 'danger')
        return redirect(url_for('faculty_course_prereqs', course_id=course_id))
    err = execute_dml("DELETE FROM PREREQUISITE WHERE course_id=%s AND prereq_course_id=%s", (course_id, int(prereq_id)))
    if err:
        flash(err, 'danger')
    else:
        flash('Prerequisite removed.', 'success')
    return redirect(url_for('faculty_course_prereqs', course_id=course_id))
        flash('Mapped account has no linked profile.', 'danger')
        return redirect(url_for('index'))

    return render_template('index.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'GET':
        depts = fetch_all("SELECT dept_id, dept_name FROM DEPARTMENT ORDER BY dept_name")
        return render_template('register.html', depts=depts)

    role = (request.form.get('role') or '').strip()  # 'student' or 'faculty'
    email = (request.form.get('email') or '').strip()
    dept_id = request.form.get('dept_id')
    username = (request.form.get('username') or '').strip()
    password = request.form.get('password') or ''

    conn = get_conn()
    if not conn:
        flash('Database connection failed.', 'danger')
        return redirect(url_for('register'))
    cur = conn.cursor()
    try:
        if role == 'student':
            first_name = (request.form.get('first_name') or '').strip()
            last_name = (request.form.get('last_name') or '').strip()
            enrollment_year = request.form.get('enrollment_year')
            if not all([first_name, last_name, email, dept_id, enrollment_year, username, password]):
                flash('Please fill all fields.', 'danger')
                return redirect(url_for('register'))
            cur.execute("SELECT COALESCE(MAX(student_id),0)+1 FROM STUDENT")
            next_id = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO STUDENT (student_id, first_name, last_name, email, dept_id, enrollment_year) VALUES (%s,%s,%s,%s,%s,%s)",
                (next_id, first_name, last_name, email, int(dept_id), int(enrollment_year))
            )
            cur.execute(
                "INSERT INTO USER_ACCOUNT (username, password_hash, role, student_id) VALUES (%s, SHA2(%s,256), 'student', %s)",
                (username, password, next_id)
            )
            conn.commit()
            session['role'] = 'student'
            session['user_id'] = int(next_id)
            flash('Registration successful. Welcome!', 'success')
            return redirect(url_for('student_dashboard'))

        elif role == 'faculty':
            full_name = (request.form.get('full_name') or '').strip()
            if not all([full_name, email, dept_id, username, password]):
                flash('Please fill all fields.', 'danger')
                return redirect(url_for('register'))
            cur.execute("SELECT COALESCE(MAX(faculty_id),0)+1 FROM FACULTY")
            next_fid = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO FACULTY (faculty_id, full_name, email, dept_id) VALUES (%s,%s,%s,%s)",
                (next_fid, full_name, email, int(dept_id))
            )
            cur.execute(
                "INSERT INTO USER_ACCOUNT (username, password_hash, role, faculty_id) VALUES (%s, SHA2(%s,256), 'faculty', %s)",
                (username, password, next_fid)
            )
            conn.commit()
            session['role'] = 'faculty'
            session['user_id'] = int(next_fid)
            flash('Registration successful. Welcome!', 'success')
            return redirect(url_for('faculty_dashboard'))

        else:
            flash('Please select a valid role to register.', 'danger')
            return redirect(url_for('register'))
    except mysql.connector.Error as err:
        conn.rollback()
        flash(f'Error creating account: {getattr(err, "msg", str(err))}', 'danger')
        return redirect(url_for('register'))
    finally:
        cur.close()
        conn.close()

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

# ---- Student ----
@app.route('/student/dashboard')
def student_dashboard():
    if session.get('role') != 'student':
        flash('Please log in as a student.', 'danger')
        return redirect(url_for('index'))

    sid = session['user_id']
    total = fetch_one("SELECT total_credits(%s) AS total_credits", (sid,))
    total_credits = total['total_credits'] if total else 0

    student_row = fetch_one("SELECT CONCAT(first_name,' ',last_name) AS name FROM STUDENT WHERE student_id=%s", (sid,))
    student_name = student_row['name'] if student_row else 'Unknown Student'

    registered = fetch_all(
        """
        SELECT r.reg_id, c.title, c.credits, s.semester_name, r.grade, o.section, o.offering_id
        FROM REGISTRATION r
        JOIN OFFERING o ON o.offering_id = r.offering_id
        JOIN COURSE c ON c.course_id = o.course_id
        JOIN SEMESTER s ON s.semester_id = o.semester_id
        WHERE r.student_id = %s
        ORDER BY s.semester_name, c.title
        """,
        (sid,)
    )

    # Available offerings not already registered (active or completed)
    available = fetch_all(
        """
        SELECT o.offering_id, c.course_id, c.title, c.credits, f.full_name AS faculty_name,
               s.semester_name, o.section,
               o.max_capacity
        FROM OFFERING o
        JOIN COURSE c ON c.course_id = o.course_id
        JOIN FACULTY f ON f.faculty_id = o.faculty_id
        JOIN SEMESTER s ON s.semester_id = o.semester_id
        WHERE o.offering_id NOT IN (
            SELECT offering_id FROM REGISTRATION WHERE student_id = %s
        )
        ORDER BY s.semester_name, c.title
        """,
        (sid,)
    )

    # Enrichment: seats remaining via view and prerequisite check
    summary_by_offering = {row['title'] + '|' + row['semester_name'] + '|' + row['section']: row
                           for row in fetch_all("SELECT * FROM VIEW_COURSE_ENROLLMENT_SUMMARY")}
    for row in available:
        # prereq check for the course
        chk = fetch_one("SELECT check_prerequisites(%s,%s) AS ok", (sid, row['course_id']))
        row['prereq_ok'] = bool(chk['ok']) if chk else True
        key = f"{row['title']}|{row['semester_name']}|{row['section']}"
        summ = summary_by_offering.get(key)
        if summ:
            row['current_enrollment'] = summ['current_enrollment']
            row['seats_remaining'] = summ['seats_remaining']
        else:
            row['current_enrollment'] = None
            row['seats_remaining'] = None

    return render_template(
        'student_dashboard.html',
        name=student_name,
        total_credits=total_credits,
        registered_courses=registered,
        available_courses=available
    )

@app.route('/register/<int:course_id>', methods=['POST'])
def register_course(course_id):
    if session.get('role') != 'student':
        flash('Unauthorized.', 'danger')
        return redirect(url_for('index'))

    sid = session['user_id']

    # 1) Prerequisite check
    chk = fetch_one("SELECT check_prerequisites(%s,%s) AS ok", (sid, course_id))
    if not chk or not chk['ok']:
        flash('Prerequisites not satisfied for this course.', 'danger')
        return redirect(url_for('student_dashboard'))

    # 2) Choose an offering to register. Prefer Spring 2025 (semester_id=1) if present
    off = fetch_one(
        """
        SELECT o.offering_id
        FROM OFFERING o
        WHERE o.course_id=%s
        ORDER BY (o.semester_id=1) DESC, o.semester_id ASC, o.section ASC
        LIMIT 1
        """,
        (course_id,)
    )
    if not off:
        flash('No offering available for this course.', 'danger')
        return redirect(url_for('student_dashboard'))

    # 3) Insert registration; triggers handle date, capacity, and time conflict
    res = execute_dml("INSERT INTO REGISTRATION (student_id, offering_id) VALUES (%s,%s)", (sid, off['offering_id']))
    if res == 'Success':
        flash('Registration successful.', 'success')
    else:
        flash(res, 'danger')
    return redirect(url_for('student_dashboard'))

@app.route('/deregister/<int:reg_id>', methods=['POST'])
def deregister(reg_id):
    if session.get('role') != 'student':
        flash('Unauthorized.', 'danger')
        return redirect(url_for('index'))
    sid = session['user_id']
    # Only allow drop if active (grade IS NULL)
    res = execute_dml("DELETE FROM REGISTRATION WHERE reg_id=%s AND student_id=%s AND grade IS NULL", (reg_id, sid))
    if res == 'Success':
        flash('Course dropped.', 'success')
    else:
        flash(res, 'danger')
    return redirect(url_for('student_dashboard'))

# ---- Faculty ----
@app.route('/faculty/dashboard')
def faculty_dashboard():
    if session.get('role') != 'faculty':
        flash('Please log in as faculty.', 'danger')
        return redirect(url_for('index'))

    fid = session['user_id']
    fac = fetch_one("SELECT full_name AS name FROM FACULTY WHERE faculty_id=%s", (fid,))
    name = fac['name'] if fac else 'Faculty'

    rows = fetch_all(
        """
        SELECT o.offering_id, c.title AS course_title, o.section, s.semester_name,
               r.reg_id, st.student_id, CONCAT(st.first_name,' ',st.last_name) AS student_name, r.grade
        FROM OFFERING o
        JOIN COURSE c ON c.course_id=o.course_id
        JOIN SEMESTER s ON s.semester_id=o.semester_id
        LEFT JOIN REGISTRATION r ON r.offering_id=o.offering_id
        LEFT JOIN STUDENT st ON st.student_id=r.student_id
        WHERE o.faculty_id=%s
        ORDER BY c.title, o.section, student_name
        """,
        (fid,)
    )

    # Group by (course_title, section, semester)
    courses = {}
    for row in rows:
        key = (row['course_title'], row['section'], row['semester_name'])
        courses.setdefault(key, []).append(row)

    return render_template('faculty_dashboard.html', name=name, courses_data=courses)

@app.route('/faculty/update_grade', methods=['POST'])
def update_grade():
    if session.get('role') != 'faculty':
        flash('Unauthorized.', 'danger')
    reg_id = request.form.get('reg_id')
    grade = (request.form.get('grade') or '').strip().upper()
    if not reg_id or not grade:
        flash('Missing registration or grade.', 'danger')
        return redirect(url_for('faculty_dashboard'))
    res = execute_dml("UPDATE REGISTRATION SET grade=%s WHERE reg_id=%s", (grade, reg_id))
    flash('Grade updated.' if res == 'Success' else res, 'success' if res == 'Success' else 'danger')
    return redirect(url_for('faculty_dashboard'))

# ---- Admin ----
@app.route('/admin/dashboard')
def admin_dashboard():
    if session.get('role') != 'admin':
        flash('Please log in as admin.', 'danger')
        return redirect(url_for('index'))
    enrollment = fetch_all("SELECT * FROM VIEW_COURSE_ENROLLMENT_SUMMARY")
    gpa = fetch_all("SELECT * FROM VIEW_STUDENT_GPA")
    total_students = fetch_one("SELECT COUNT(*) AS c FROM STUDENT")['c']
    total_faculty = fetch_one("SELECT COUNT(*) AS c FROM FACULTY")['c']
    total_offerings = fetch_one("SELECT COUNT(*) AS c FROM OFFERING")['c']
    active_regs = fetch_one("SELECT COUNT(*) AS c FROM REGISTRATION WHERE grade IS NULL")['c']
    util = fetch_one("SELECT SUM(current_enrollment) AS se, SUM(max_capacity) AS sc FROM VIEW_COURSE_ENROLLMENT_SUMMARY")
    utilization = 0.0
    if util and util['sc']:
        try:
            se = float(util['se'] or 0)
            sc = float(util['sc'] or 0)
            utilization = round((se * 100.0 / sc), 1) if sc > 0 else 0.0
        except Exception:
            utilization = 0.0
    metrics = {
        'students': total_students,
        'faculty': total_faculty,
        'offerings': total_offerings,
        'active_regs': active_regs,
        'utilization': utilization
    }
    return render_template('admin_dashboard.html', enrollment=enrollment, gpa=gpa, metrics=metrics)

if __name__ == '__main__':
    app.run(debug=True)