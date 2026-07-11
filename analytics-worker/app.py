import os
import json
import logging
from flask import Flask, jsonify, request
from celery import Celery
from pythonjsonlogger import jsonlogger
import boto3

# 1. Enforce Structured JSON Logging for CloudWatch Audit Trails
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter('%(asctime)s %(levelname)s %(name)s %(message)s')
logHandler.setFormatter(formatter)
logger = logging.getLogger("analytics_worker")
logger.addHandler(logHandler)
logger.setLevel(logging.INFO)

# 2. Initialize Flask & Celery
app = Flask(__name__)

REDIS_URL = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')

# SECURE CONFIGURATION: Restrict serialization strictly to JSON to eliminate RCE flaws
celery_app = Celery(
    'tasks',
    broker=REDIS_URL,
    backend=REDIS_URL,
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json'
)

S3_BUCKET = os.environ.get('AWS_STORAGE_BUCKET_NAME')

# 3. Light-weight Kubernetes Probes Endpoint
@app.route('/healthz', methods=['GET'])
def healthz():
    # Ensure our connection to the broker is alive before declaring health
    try:
        celery_app.control.ping(timeout=0.5)
        return jsonify({"status": "healthy", "broker": "connected"}), 200
    except Exception as e:
        logger.error(f"Healthcheck failed: {str(e)}")
        return jsonify({"status": "unhealthy", "reason": "Broker unreachable"}), 500

# 4. Trigger Endpoint (Called internally by the Core Logic Layer)
@app.route('/api/v1/analytics/report', methods=['POST'])
def trigger_report():
    tenant_id = request.headers.get('X-Tenant-ID')
    user_sub = request.headers.get('X-User-Sub')
    
    if not tenant_id or not user_sub:
        return jsonify({"error": "Missing mandatory tenancy context"}), 400
        
    data = request.get_json() or {}
    report_type = data.get('report_type', 'default')

    # Dispatch task asynchronously to the Celery worker cluster
    task = generate_tenant_report.delay(tenant_id, user_sub, report_type)
    
    logger.info(f"Dispatched task {task.id} for tenant {tenant_id}")
    return jsonify({"task_id": task.id, "status": "Queued"}), 202

# 5. Asynchronous Worker Task Blueprint
@celery_app.task(bind=True, max_retries=3)
def generate_tenant_report(self, tenant_id, user_sub, report_type):
    """
    Long-running worker job execution context.
    Executes in the background deployment, entirely separate from the Flask HTTP thread.
    """
    logger.info(f"Starting long-running report for tenant: {tenant_id}, triggered by: {user_sub}")
    
    try:
        # Simulate heavy data calculation/aggregation
        import time
        time.sleep(5) 
        
        report_data = {
            "tenant_id": tenant_id,
            "generated_by": user_sub,
            "type": report_type,
            "metrics": {"total_sales": 540200, "active_users": 1250}
        }
        
        # CRITICAL SECURITY GATE: Tenant-isolated S3 storage paths
        # Prevents Tenant A from guessing the object key of Tenant B's reports (Insecure Direct Object Reference)
        s3_key = f"tenants/{tenant_id}/analytics/reports/{self.request.id}.json"
        
        # IRSA Context Check: boto3 client relies on IAM Role assumed by the EKS Service Account
        s3 = boto3.client('s3')
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=json.dumps(report_data),
            ContentType='application/json'
        )
        
        logger.info(f"Successfully archived report to S3 payload path: {s3_key}")
        return {"status": "Complete", "location": s3_key}

    except Exception as exc:
        logger.error(f"Task failed. Retrying... Error: {str(exc)}")
        # Exponential backoff retry logic to handle transient database/network spikes
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)