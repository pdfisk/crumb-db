App.find_or_create_by!(name: "hello.py", language: "python") { |r| r.content = 'print("Hello, world!")' }
App.find_or_create_by!(name: "hello.bas", language: "basic") { |r| r.content = 'Print "Hello, world!"' }
