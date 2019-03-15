import sys


def main():
    if len(sys.argv) != 4:
        print("usage: build_query.py <columns> <table-name> <high-entropy-string>")
        exit(1)

    sql_columns_string = sys.argv[1]
    table_name = sys.argv[2]
    high_entropy_string = sys.argv[3]

    query = "SELECT REPLACE_ME FROM " + table_name

    replace_me_string = ""
    lines = sql_columns_string.split("\n")
    for i in range(0, len(lines)):
        sql_columns = lines[i].split("\t")
        column_name = sql_columns[0]
        nullable = sql_columns[2]

        if nullable == "YES":
            replace_me_string += " coalesce(" + column_name + ", \"" + high_entropy_string + "\")"
        else:
            replace_me_string += column_name

        if i < len(lines) - 1:
            replace_me_string += ", "

    print(query.replace("REPLACE_ME", replace_me_string))
    exit(0)


main()
