import random
import csv
import datetime

def generate_books_data(num_books):
    countries = ['PL', 'ENG']
    genres = ['Fantastyka', 'Romans', 'Kryminal', 'Thriller', 'Science Fiction', 'Literatura faktu', 'Historyczna']
    books_data = []
    books_data.append(['book_id', 'title', 'author', 'genre', 'descr', 'country', 'netto_value', 'vat', 'brutto_value'])
    for i in range(num_books):
        book_id = i + 1
        title = f"Ksiazka nr {book_id}"
        author = f"Autor {random.randint(1, 10)}"
        genre = random.choice(genres)
        description = f"Krotki opis ksiazki nr {book_id}"
        country = random.choice(countries)
        netto_value = round(random.uniform(10, 50), 2)
        vat = 0.23
        brutto_value = round(netto_value * (1 + vat), 2)
        books_data.append([book_id, title, author, genre, description, country, netto_value, vat, brutto_value])
    return books_data

def generate_sales_data(num_sales, num_books, num_clients, books_data):
    clients = {}
    for i in range(num_clients):
        client_name = f"Klient {i}"
        clients[client_name] = f"{random.randint(1000000000, 2147483647)}"

    sales_data = []
    sales_data.append(['sales_id', 'sale_date', 'client_name', 'client_nip', 'book_id', 'quantity_sold', 'unit_price', 'netto_value', 'brutto_value'])
    for i in range(num_sales):
        sales_id = random.randint(1, 2147483647)

        current_date = datetime.datetime.now()
        days_delta = random.randint(1, 365)
        sale_date = current_date - datetime.timedelta(days=days_delta)
        sale_date = sale_date.strftime("%Y-%m-%d")  # datetime.datetime.now().strftime("%Y-%m-%d")

        client = random.choice(list(clients.items()))
        client_name = client[0]
        nip = client[1]

        book_id = random.randint(1, num_books)
        book = find_book_by_id(book_id, books_data)

        quantity_sold = random.randint(1, 10)
        unit_price = book[6]
        vat = book[7]

        netto_value = round(quantity_sold * unit_price, 2)
        brutto_value = round((1 + float(vat)) * netto_value, 2)
        sales_data.append([sales_id, sale_date, client_name, nip, book_id, quantity_sold, unit_price, netto_value, brutto_value])
    return sales_data


def find_book_by_id(book_id, books_data):
    for book in books_data:
        if book[0] == book_id:
            return book
    return None

def write_data_to_file(data, filename):
    with open(filename, 'w', encoding='utf-8', newline='') as file:
        writer = csv.writer(file, delimiter='\t')
        writer.writerows(data)

if __name__ == "__main__":
    num_books = 10
    num_sales = 10
    num_clients = 5

    books_data = generate_books_data(num_books)
    sales_data = generate_sales_data(num_sales, num_books, num_clients, books_data)

    print('Books:')
    print(books_data)
    print('Sales:')
    print(sales_data)

    write_data_to_file(books_data, "books_data.txt")
    write_data_to_file(sales_data, "sales_data.txt")
