# Reproduces the environment notebooks/day8_statistics.ipynb was built and
# verified in (package versions matched to that session's installed
# versions), plus numpy pinned below 2.x -- the host machine's anaconda env
# hit real numpy-2/pandas-extension incompatibilities (numexpr, bottleneck)
# during this project; pinning here avoids reproducing that bug.
FROM python:3.11-slim

WORKDIR /workspace

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8888

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser"]
