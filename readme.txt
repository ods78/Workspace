# Data Engineering & Analytics Workspace

A comprehensive collection of data engineering tools, databases, and analytics platforms for modern data infrastructure.

## 🎯 About

This workspace contains containerized deployments and configurations for various data engineering tools, databases, and analytics platforms. Each project is designed to work independently or as part of a larger data ecosystem.

## 📊 Projects Overview

### 🗄️ Databases & Data Storage

#### **ClickHouse**
- **Description**: High-performance columnar OLAP database
- **Use Case**: Real-time analytics, time-series data, fast aggregations
- **Features**: Standalone ClickHouse deployment
- **Path**: `./ClickHouse/`

#### **ClickHouse with Load Balancer**
- **Description**: Scalable ClickHouse deployment with load balancing
- **Use Case**: High-availability analytics workloads
- **Features**: Multiple ClickHouse nodes with load balancer
- **Path**: `./clickhouseWithLoadbalancer/`

#### **PostgreSQL**
- **Description**: Robust relational database system
- **Use Case**: OLTP workloads, data storage, application backend
- **Features**: Production-ready PostgreSQL setup
- **Path**: `./PostgreSQL/`

### 🏗️ Data Lake & Processing

#### **Dremio**
- **Description**: Data lakehouse platform for self-service analytics
- **Use Case**: Data virtualization, query acceleration, data catalog
- **Features**: Complete Dremio deployment as data lakehouse solution
- **Path**: `./Dremio/`

#### **Apache NiFi with Registry**
- **Description**: Data flow automation and registry management
- **Use Case**: ETL/ELT pipelines, data ingestion, flow versioning
- **Features**: NiFi with integrated registry for version control
- **Path**: `./nifiWithRegistry/`

### 📈 Analytics & Visualization

#### **Redash**
- **Description**: Open-source business intelligence and data visualization
- **Use Case**: Dashboards, data exploration, business reporting
- **Features**: Complete Redash deployment with database backend
- **Path**: `./redash/`

## 🏗️ Architecture Overview

```mermaid
graph TB
    A[Data Sources] --> B[Apache NiFi]
    B --> C[PostgreSQL]
    B --> D[ClickHouse]
    B --> E[Data Lake]
    
    E --> F[Dremio]
    C --> F
    D --> F
    
    F --> G[Redash]
    D --> G
    C --> G
    
    H[Load Balancer] --> I[ClickHouse Cluster]
