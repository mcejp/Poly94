#!/usr/bin/env python3

"""
CREATE TABLE public.builds (
    id serial NOT NULL,
    pipeline_timestamp timestamp(0) NOT NULL,
    pipeline_url varchar NOT NULL,
    branch varchar NOT NULL,
    commit_sha1 varchar(40) NOT NULL,
    commit_timestamp timestamp(0) NOT NULL,
    "attributes" json NULL,
    CONSTRAINT builds_pk PRIMARY KEY (id)
);
"""

import json
import os

import psycopg


results = {}
results["commit_title"] = os.environ["CI_COMMIT_TITLE"]


# Results of simulation

try:
    with open("results.xml", "rt") as f:
        xml = f.read()

    if "<failure" not in xml:
        results["sim"] = dict(result="pass")
    else:
        results["sim"] = dict(result="fail")
except FileNotFoundError:
    results["sim"] = dict(result=None)

# TODO: refactor completely to (probably) save results for individual tests
if os.path.exists("verilator.fail"):
    results["sim"]["result"] = "fail"
elif not os.path.exists("verilator.pass"):
    results["sim"]["result"] = None

# Results of P&R

try:
    with open("build/nextpnr-report.json", "rt") as f:
        report = json.load(f)

    results["build"] = dict(result="pass",
                            fmax=report["fmax"],
                            utilization=report["utilization"]
                            )
except FileNotFoundError:
    results["build"] = dict(result="fail")


# Connect to DB

with psycopg.connect(os.environ["POSTGRES_CONN_STRING"]) as conn:
    cursor = conn.cursor()
    cursor.execute('INSERT INTO builds(pipeline_timestamp, pipeline_url, branch, commit_sha1, commit_timestamp, "attributes") VALUES (%s, %s, %s, %s, %s, %s)', (
        os.environ["CI_PIPELINE_CREATED_AT"],
        os.environ["CI_PIPELINE_URL"],
        os.environ["CI_COMMIT_BRANCH"],
        os.environ["CI_COMMIT_SHA"],
        os.environ["CI_COMMIT_TIMESTAMP"],
        json.dumps(results))
    )
