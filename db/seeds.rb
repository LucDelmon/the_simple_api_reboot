# frozen_string_literal: true
john = Author.create!(name: "John Doe")
jane = Author.create!(name: "Jane Doe")
Book.create!(title: "Book 1", page_count: 100, author: john)
Book.create!(title: "Book 2", page_count: 200, author: jane)
Book.create!(title: "Book 3", page_count: 30, author: john)
