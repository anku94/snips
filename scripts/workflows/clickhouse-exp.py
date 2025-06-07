import clickhouse_connect
import numpy as np

client = clickhouse_connect.get_client(host='localhost', username='default', password='', http_proxy=None, https_proxy=None)
