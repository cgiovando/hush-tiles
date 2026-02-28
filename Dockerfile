FROM public.ecr.aws/lambda/python:3.12

# System libs needed by GDAL/rasterio/pyproj
RUN dnf install -y expat libxml2 libcurl-minimal && dnf clean all

RUN pip install titiler.application mangum --no-cache-dir

# Lambda handler that wraps the TiTiler FastAPI app with Mangum
COPY handler.py ${LAMBDA_TASK_ROOT}/

CMD ["handler.handler"]
