#!/bin/bash
# Create a log file to monitor the setup process
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting setup script at $(date)"

# Update system packages
echo "Updating system packages..."
yum update -y || { echo "Failed to update packages"; exit 1; }

# Install Docker
echo "Installing Docker..."
amazon-linux-extras install docker -y || { echo "Failed to install docker"; exit 1; }
systemctl start docker || { echo "Failed to start docker service"; exit 1; }
systemctl enable docker || { echo "Failed to enable docker service"; exit 1; }
usermod -a -G docker ec2-user

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo "Failed to download docker-compose"; exit 1; }
chmod +x /usr/local/bin/docker-compose || { echo "Failed to make docker-compose executable"; exit 1; }

# Create application directory
echo "Creating application directory..."
mkdir -p /home/ec2-user/bookstore-api

# Create Bookstore API
echo "Creating Bookstore API Python file..."
cat > /home/ec2-user/bookstore-api/bookstore-api.py << 'EOF'
from flask import Flask, jsonify, abort, request, make_response, send_file
from flaskext.mysql import MySQL

app = Flask(__name__)
app.config['MYSQL_DATABASE_HOST'] = 'database'
app.config['MYSQL_DATABASE_USER'] = 'clarusway'
app.config['MYSQL_DATABASE_PASSWORD'] = 'Clarusway_1'
app.config['MYSQL_DATABASE_DB'] = 'bookstore_db'
app.config['MYSQL_DATABASE_PORT'] = 3306
mysql = MySQL()
mysql.init_app(app)
connection = mysql.connect()
connection.autocommit(True)
cursor = connection.cursor()

def init_bookstore_db():
    drop_table = 'DROP TABLE IF EXISTS bookstore_db.books;'
    books_table = """
    CREATE TABLE bookstore_db.books(
    book_id INT NOT NULL AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    author VARCHAR(100),
    is_sold BOOLEAN NOT NULL DEFAULT 0,
    PRIMARY KEY (book_id)
    )ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    """
    data = """
    INSERT INTO bookstore_db.books (title, author, is_sold)
    VALUES
        ("Where the Crawdads Sing", "Delia Owens", 1 ),
        ("The Vanishing Half: A Novel", "Brit Bennett", 0),
        ("1st Case", "James Patterson, Chris Tebbetts", 0);
    """
    cursor.execute(drop_table)
    cursor.execute(books_table)
    cursor.execute(data)

@app.route('/frontend')
def serve_frontend():
    return send_file('bookstore-frontend.html')

@app.route('/')
def home():
    return "Welcome to Bookstore API Service"

@app.route('/books', methods=['GET'])
def get_books():
    query = "SELECT * FROM books;"
    cursor.execute(query)
    result = cursor.fetchall()
    books = [{'book_id':row[0], 'title':row[1], 'author':row[2], 'is_sold': bool(row[3])} for row in result]
    return jsonify({'books': books})

if __name__== '__main__':
    init_bookstore_db()
    app.run(host='0.0.0.0', port=80)
EOF

# Create Dockerfile
echo "Creating Dockerfile..."
cat > /home/ec2-user/bookstore-api/Dockerfile << 'EOF'
FROM python:3.9-slim
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
EXPOSE 80
CMD ["python", "bookstore-api.py"]
EOF

# Create Docker Compose file
echo "Creating docker-compose.yml..."
cat > /home/ec2-user/bookstore-api/docker-compose.yml << 'EOF'
version: '3.7'

services:
  database:
    image: mysql:5.7
    container_name: database
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: 123456
      MYSQL_DATABASE: bookstore_db
      MYSQL_USER: clarusway
      MYSQL_PASSWORD: Clarusway_1
    networks:
      - clarusnet

  myapp:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: bookstoreapi
    restart: always
    depends_on:
      - database
    ports:
      - "80:80"
    networks:
      - clarusnet

networks:
  clarusnet:
EOF

# Create requirements.txt
echo "Creating requirements.txt..."
cat > /home/ec2-user/bookstore-api/requirements.txt << 'EOF'
flask==2.0.1
flask-mysql==1.5.2
EOF

# Create frontend HTML
echo "Creating frontend HTML..."
cat > /home/ec2-user/bookstore-api/bookstore-frontend.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Bookstore API Frontend</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        .book { border: 1px solid #ddd; margin: 10px; padding: 10px; }
        button { cursor: pointer; padding: 5px 10px; }
    </style>
</head>
<body>
    <h1>Bookstore API</h1>
    <div id="books"></div>
    <script>
        fetch('/books')
            .then(response => response.json())
            .then(data => {
                const booksDiv = document.getElementById('books');
                data.books.forEach(book => {
                    const bookDiv = document.createElement('div');
                    bookDiv.className = 'book';
                    bookDiv.innerHTML = `
                        <h3>${book.title}</h3>
                        <p>Author: ${book.author || 'Unknown'}</p>
                        <p>Status: ${book.is_sold ? 'Sold' : 'Available'}</p>
                    `;
                    booksDiv.appendChild(bookDiv);
                });
            })
            .catch(error => {
                document.getElementById('books').innerHTML = 
                    `<p style="color: red;">Error loading books: ${error.message}</p>`;
            });
    </script>
    <footer>
        <p class="dev-title">DEVELOPERS</p>
        <p>Hassan Rais • Muhammad Adeel • Hamza Zaidi • Nauman Ali Murad</p>
        <small>For CE308 Cloud Computing Course • Instructor: Miss Safia Baloch</small>
    </footer>
</body>
</html>
EOF

# Set proper permissions
echo "Setting permissions..."
chown -R ec2-user:ec2-user /home/ec2-user/bookstore-api

# Start the application with error handling
echo "Starting the application..."
cd /home/ec2-user/bookstore-api

# Build and start the containers with error handling
echo "Building and starting Docker containers..."
docker-compose up -d || { echo "Failed to start Docker Compose services"; cat docker-compose.log; exit 1; }

# Verify services are running
echo "Verifying services are running..."
docker-compose ps
docker ps

# Install additional useful tools
echo "Installing git..."
yum install -y git 

echo "Setup completed at $(date)"
echo "You can access the application at http://$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)" 