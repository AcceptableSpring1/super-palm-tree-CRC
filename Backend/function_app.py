import azure.functions as func
import logging
from azure.data.tables import TableServiceClient, UpdateMode
from azure.core.exceptions import ResourceNotFoundError
import os
import json

app = func.FunctionApp()

partition_key = "Counter"
row_key = "visitors"

def get_table_client():
    conn_str = os.environ.get("COSMOS_TABLE_CONNECTION_STRING")
    table_name = os.environ.get("TABLE_NAME")

    if not conn_str or not table_name:
        raise RuntimeError("Missing COSMOS_TABLE_CONNECTION_STRING or TABLE_NAME app setting")

    table_service = TableServiceClient.from_connection_string(conn_str)
    return table_service.get_table_client(table_name=table_name)

@app.route(route="visitorcounter", auth_level=func.AuthLevel.ANONYMOUS, methods=["POST"])
def visitorcounter(req: func.HttpRequest) -> func.HttpResponse:
    try:
        table_client = get_table_client()

        try:
            entity = table_client.get_entity(partition_key=partition_key, row_key=row_key)
            count = int(entity.get("count", 0)) + 1
            entity["count"] = count
            table_client.update_entity(entity=entity, mode=UpdateMode.REPLACE)

        except ResourceNotFoundError:
            count = 1
            entity = {"PartitionKey": partition_key, "RowKey": row_key, "count": count}
            table_client.create_entity(entity=entity)

        return func.HttpResponse(
            body=json.dumps({"visits": count}),
            mimetype="application/json",
            status_code=200
        )

    except Exception as e:
        logging.exception("visitorcounter failed")
        return func.HttpResponse(
            body=json.dumps({"error": str(e)}),
            mimetype="application/json",
            status_code=500
        )