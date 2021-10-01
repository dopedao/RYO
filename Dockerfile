FROM python:3.7-buster
RUN pip install --upgrade cairo-lang
RUN starknet --version