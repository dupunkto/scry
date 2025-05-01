FROM python:3.10
WORKDIR /app
COPY ./requirements.txt requirements.txt
RUN pip install --no-cache-dir --upgrade -r requirements.txt
RUN git config --global --add safe.directory '*'
RUN git config --global user.email "scry@dupunkto.org"
RUN git config --global user.name "Scry"
COPY . .
CMD ["gunicorn", "--bind", "0.0.0.0:4000", "app:app"]