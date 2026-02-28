FROM public.ecr.aws/lambda/python:3.12

RUN pip install titiler.application mangum --no-cache-dir

# Lambda handler that wraps the TiTiler FastAPI app with Mangum
COPY handler.py ${LAMBDA_TASK_ROOT}/

CMD ["handler.handler"]
