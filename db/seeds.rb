PythonSource.find_or_create_by!(name: "hello.py") { |r| r.content = 'print("Hello, world!")' }
BasicSource.find_or_create_by!(name: "hello.bas") { |r| r.content = '10 PRINT "HELLO, WORLD!"' }
