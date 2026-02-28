"""AWS Lambda handler wrapping TiTiler with Mangum."""

from mangum import Mangum
from titiler.application.main import app

handler = Mangum(app, lifespan="off")
