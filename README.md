# Microsoft DP-800: SQL Server & AI Database Developer Masterclass 🚀

[![Microsoft Azure](https://img.shields.io/badge/Microsoft-SQL%20Server%202022-blue.svg?style=flat-square&logo=microsoftsqlserver)](https://www.microsoft.com/sql-server)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Status: Active](https://img.shields.io/badge/Status-Active-brightgreen.svg?style=flat-square)]()

A comprehensive repository for mastering **Microsoft DP-800 (Microsoft SQL Server AI Developer)**, covering enterprise database design, advanced T-SQL programmability, performance tuning, and AI-ready database architectures.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Repository Structure](#-repository-structure)
- [Modules & Core Topics](#-modules--core-topics)
  - [Domain 1: Database Design & Development (35–40%)](#domain-1-database-design--development-3540)
  - [Advanced T-SQL Programmability](#advanced-t-sql-programmability)
  - [Module Guides & Theory](#module-guides--theory)
- [Getting Started](#-getting-started)
- [Prerequisites](#-prerequisites)
- [License](#-license)

---

## 💡 Overview

This repository serves as a hands-on technical guide and code laboratory for candidates preparing for the **DP-800: Microsoft SQL Server AI Developer** certification or database architects building high-performance, scalable SQL Server applications.

Key architectural concepts implemented in T-SQL:
* **Relational & Modern Storage Models**: Normalization (1NF–5NF), Temporal Tables, Graph Databases (`MATCH`, `SHORTEST_PATH`), In-Memory OLTP.
* **Indexing & Partitioning Strategies**: Clustered, Nonclustered, Filtered, Columnstore, Partition Switching & Archiving.
* **Programmability & Logic**: Idempotent DDL, Stored Procedures, UDFs, Triggers, Native Compilation.
* **Transaction Management & Concurrency**: Isolation levels (`READ COMMITTED`, `SNAPSHOT`, `SERIALIZABLE`), Error Handling (`TRY...CATCH`, `XACT_ABORT`), Optimistic vs. Pessimistic Locking.

---

## 📁 Repository Structure

```text
DP-800-SQL-AI/
├── Antigravity_DP800_Database_Objects.sql            # Core DDL: Tables, Constraints, Partitioning, Temporal & Graph DBs
├── Antigravity_DP800_Programmability_and_Advanced_TSQL.sql # Advanced T-SQL: Stored Procs, Functions, Triggers, Memory-Optimized
├── Antigravity_DP800_Module1_Guide.md                 # Executive Study Guide: Domain 1 Theory & Best Practices
├── Codex_DP800_Mien1.md                               # In-depth architectural guide for DP-800 Domain 1
├── Reviews.sql                                        # Practice SQL queries & verification scenarios
├── PupilData.csv                                      # Sample dataset for bulk insert and ETL testing
├── StartOfSection*.sql                                # Modular T-SQL code scripts per curriculum section
├── .gitignore                                         # Version control ignore rules
└── README.md                                          # Master documentation
```

---

## 📚 Modules & Core Topics

### Domain 1: Database Design & Development (35–40%)

The script [`Antigravity_DP800_Database_Objects.sql`](./Antigravity_DP800_Database_Objects.sql) implements end-to-end database structures:

1. **Table Design & Integrity**: Primary Keys, Foreign Keys (`CASCADE` vs `NO ACTION`), Check Constraints, Unique Constraints.
2. **Indexing Strategies**:
   - B-Tree Clustered & Nonclustered Indexes with `INCLUDE` columns.
   - Filtered Indexes for sparse data.
   - Columnstore Indexes for analytical & hybrid workloads (HTAP).
3. **Partitioning**: Partition Functions, Partition Schemes, and sliding-window partition management.
4. **Specialized Storage**:
   - System-Versioned Temporal Tables for audit logging & point-in-time point-in-time querying (`FOR SYSTEM_TIME`).
   - SQL Graph Tables (`NODE`, `EDGE`) for complex relationship modeling.

---

### Advanced T-SQL Programmability

The script [`Antigravity_DP800_Programmability_and_Advanced_TSQL.sql`](./Antigravity_DP800_Programmability_and_Advanced_TSQL.sql) demonstrates enterprise-grade server-side code:

1. **Stored Procedures & UDFs**:
   - Business transaction procedures with output parameters.
   - Inline Table-Valued Functions (iTVFs) vs Multi-Statement TVFs (mTVFs) performance patterns.
2. **Triggers**:
   - `AFTER` Triggers for audit logging.
   - `INSTEAD OF` Triggers for complex view updates.
3. **Robust Error Handling**:
   - Transactional safety using `SET XACT_ABORT ON` and `XACT_STATE()`.
   - Structured `TRY...CATCH` blocks with custom error logging (`THROW`).
4. **In-Memory OLTP**:
   - Memory-Optimized Tables with `MEMORY_OPTIMIZED=ON` and `DURABILITY=SCHEMA_AND_DATA`.
   - Natively Compiled Stored Procedures (`WITH NATIVE_COMPILATION`).

---

### Module Guides & Theory

- 📘 [`Antigravity_DP800_Module1_Guide.md`](./Antigravity_DP800_Module1_Guide.md): Detailed breakdowns of DP-800 exam requirements, trade-off analyses, and design patterns.
- 📙 [`Codex_DP800_Mien1.md`](./Codex_DP800_Mien1.md): Deep dive into normalization, concurrency control, and index optimization strategy.

---

## 🛠️ Getting Started

### Prerequisites

* **Database Engine**: Microsoft SQL Server 2022 / Azure SQL Database / SQL Server Developer Edition.
* **Management Tool**: SQL Server Management Studio (SSMS) 19+ or Azure Data Studio.

### Execution Order

1. Run [`Antigravity_DP800_Database_Objects.sql`](./Antigravity_DP800_Database_Objects.sql) to create the schema, tables, constraints, indexes, and graph nodes.
2. Run [`Antigravity_DP800_Programmability_and_Advanced_TSQL.sql`](./Antigravity_DP800_Programmability_and_Advanced_TSQL.sql) to deploy stored procedures, functions, triggers, and memory-optimized objects.
3. Execute practice scripts in `StartOfSection*.sql` and `Reviews.sql` to test queries and workload performance.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Maintained by WhiteKingDataScience & Antigravity AI* 🚀
