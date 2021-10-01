FROM python:3.7-buster
RUN pip install cairo-lang
RUN starknet --version