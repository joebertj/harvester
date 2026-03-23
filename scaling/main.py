import asyncio
import uvicorn
import numpy as np
import time
import math
from fastapi import FastAPI
from prometheus_client import make_asgi_app, Gauge

app = FastAPI()
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Custom Metric
simulated_user_load = Gauge('simulated_user_load', 'Simulated user load using Poisson distribution')

async def update_metrics():
    while True:
        # Oscillate the mean (lambda) between 2 and 18 over a ~5 minute period
        current_time = time.time()
        dynamic_lam = 10 + 8 * math.sin(current_time / 50.0)
        
        # Generate Poisson distribution around the oscillating mean
        load = np.random.poisson(lam=max(1, dynamic_lam))
        simulated_user_load.set(load)
        await asyncio.sleep(5)
        
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(update_metrics())

@app.get("/")
def read_root():
    return {"status": "running", "metric": "simulated_user_load"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
