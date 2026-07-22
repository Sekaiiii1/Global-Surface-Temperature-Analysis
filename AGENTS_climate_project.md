~~# AGENTS.md

## 1. Project Overview

**Project name:** Climate Change: Earth Surface Temperature Analysis  
**Project leader:** Sekai  
**Team size:** 5 members  

### Main objective

Build a complete data analysis and machine learning workflow for the **Climate Change: Earth Surface Temperature Data** dataset.

The project includes:

1. Raw data exploration
2. PostgreSQL data pipeline
3. Data cleaning
4. Exploratory data analysis and visualization
5. Feature engineering
6. Machine learning model training
7. Prediction demonstration
8. Streamlit/FastAPI application
9. Word and PowerPoint reports

---

## 2. Actual Project Structure

The Agent must use this structure as the project standard:

```text
project-name/
│
├── data/
│   ├── raw/                         # Original CSV files
│   ├── processed/                   # Cleaned and split datasets
│   └── sample/                      # Small sample datasets for demos
│
├── docs/                            # Project documentation
│
├── notebooks/
│   ├── 01_data_understanding.ipynb  # Read CSV, inspect and explore data
│   ├── 02_postgresql_pipeline.ipynb # PostgreSQL ETL pipeline
│   ├── 03_data_cleaning.ipynb       # Missing values, outliers, cleaning
│   ├── 04_eda_visualization.ipynb   # EDA and visualizations
│   ├── 05_feature_engineering.ipynb # Feature creation and insights
│   ├── 06_machine_learning.ipynb    # Train, test and compare models
│   └── 07_prediction_demo.ipynb     # Load trained model and predict
│
├── sql/
│   ├── 01_create_tables.sql         # Create PostgreSQL tables
│   ├── 02_import_data.sql           # Import data into PostgreSQL
│   ├── 03_views.sql                 # Create database views
│   ├── 04_aggregation.sql           # Aggregation and analysis queries
│   └── 05_indexes.sql               # Create database indexes
│
├── prompts/                         # Prompts used with AI agents
│
├── app/                             # Streamlit and FastAPI application
│   ├── streamlit_app.py             # Main Streamlit application
│   ├── api.py                       # FastAPI backend
│   ├── utils/                       # Shared helper functions
│   ├── pages/                       # Streamlit pages
│   └── prediction.py                # Prediction logic
│
├── models/                          # Trained machine learning files
│   ├── model.pkl
│   └── scaler.pkl
│
├── reports/                         # Final report and presentation
│   ├── tai-lieu-du-an-nhom-1.docx
│   ├── slide-du-an-nhom-1.pptx
│   └── images/
│
├── README.md                        # Installation and usage guide
├── Task_Tracker.xlsx                # Team task tracking
└── requirements.txt                 # Python dependencies
```

The actual filenames in the workspace are the source of truth.  
Do not invent files that are not present.

---

## 3. Data Folder Rules

### `data/raw/`

Contains the original CSV files.

Rules:

- Treat all files in this folder as read-only.
- Never overwrite or modify the original dataset.
- Do not rename source columns without documenting the change.
- Do not commit very large raw datasets unless required.

### `data/processed/`

Contains cleaned and transformed datasets.

Expected outputs may include:

```text
train.csv
test.csv
cleaned_temperature_data.csv
feature_engineered_data.csv
```

Rules:

- Every processed file must be reproducible from code.
- Record row counts before and after cleaning.
- Document removed rows and changed columns.
- Avoid silently overwriting important files.

### `data/sample/`

Contains small datasets for:

- demonstrations
- testing
- application previews
- fast local execution

Do not use sample data as a replacement for the full dataset during final analysis.

---

## 4. Notebook Workflow

The notebooks must be developed and executed in this order:

```text
01_data_understanding.ipynb
        ↓
02_postgresql_pipeline.ipynb
        ↓
03_data_cleaning.ipynb
        ↓
04_eda_visualization.ipynb
        ↓
05_feature_engineering.ipynb
        ↓
06_machine_learning.ipynb
        ↓
07_prediction_demo.ipynb
```

Each notebook must:

1. Have a clear title.
2. State its objective.
3. Use real file paths from the workspace.
4. Contain Markdown explanations.
5. Handle common errors clearly.
6. Produce a clear output.
7. End with conclusions or findings.
8. Run from top to bottom without manual fixes.

---

## 5. Notebook Requirements

### 5.1 `01_data_understanding.ipynb`

Purpose:

- Load the original CSV files.
- Inspect dataset structure.
- Understand columns and data types.
- Identify initial data quality issues.

Required tasks:

- [ ] Import required libraries.
- [ ] Find the real CSV files in `data/raw/`.
- [ ] Load the dataset.
- [ ] Display shape.
- [ ] Display real column names.
- [ ] Inspect data types.
- [ ] Show sample rows.
- [ ] Check missing values.
- [ ] Check duplicated rows.
- [ ] Generate descriptive statistics.
- [ ] Explain the meaning of important columns.
- [ ] Write initial observations.

Do not invent dataset columns.

---

### 5.2 `02_postgresql_pipeline.ipynb`

Purpose:

- Build the PostgreSQL ETL process.
- Import data into PostgreSQL.
- Perform joins and aggregations.

Required tasks:

- [ ] Read database settings from environment variables.
- [ ] Test PostgreSQL connection.
- [ ] Create tables using SQL scripts.
- [ ] Import data.
- [ ] Validate inserted row counts.
- [ ] Perform joins when needed.
- [ ] Run aggregation queries.
- [ ] Document errors and solutions.
- [ ] Never expose database passwords.

Expected related files:

```text
sql/01_create_tables.sql
sql/02_import_data.sql
sql/03_views.sql
sql/04_aggregation.sql
sql/05_indexes.sql
```

---

### 5.3 `03_data_cleaning.ipynb`

Purpose:

- Clean missing values.
- Handle duplicated rows.
- Detect and process outliers.
- Standardize columns and values.

Required tasks:

- [ ] Define cleaning rules.
- [ ] Handle missing values.
- [ ] Handle duplicates.
- [ ] Convert incorrect data types.
- [ ] Standardize date fields.
- [ ] Validate temperature values.
- [ ] Detect outliers.
- [ ] Explain whether outliers are removed, capped, or retained.
- [ ] Save cleaned data to `data/processed/`.
- [ ] Report before-and-after row counts.

---

### 5.4 `04_eda_visualization.ipynb`

Purpose:

- Perform exploratory data analysis.
- Create meaningful charts.
- Explain climate and temperature patterns.

Suggested analyses:

- Global temperature trend over time
- Country-level temperature comparison
- City-level temperature comparison
- Monthly and yearly patterns
- Decade-level changes
- Seasonal patterns
- Temperature uncertainty
- Top warming and cooling regions

Required tasks:

- [ ] Use cleaned data.
- [ ] Create readable charts.
- [ ] Add chart titles and axis labels.
- [ ] Add observations below every important chart.
- [ ] Save important charts to `reports/images/`.
- [ ] Avoid misleading visual scales.

---

### 5.5 `05_feature_engineering.ipynb`

Purpose:

- Create useful machine learning features.
- Analyze correlations.
- Produce new insights.

Suggested features:

- year
- month
- quarter
- decade
- season
- latitude and longitude values
- lag features
- rolling averages
- temperature anomalies
- location-based encodings

Required tasks:

- [ ] Create at least 10 meaningful features when supported by the data.
- [ ] Explain each feature.
- [ ] Check feature correlation.
- [ ] Remove or document unusable features.
- [ ] Prevent target leakage.
- [ ] Save the feature dataset to `data/processed/`.

Do not force features that are unsupported by the real dataset.

---

### 5.6 `06_machine_learning.ipynb`

Purpose:

- Train and compare machine learning models.
- Select the best model.
- Save the trained model.

Required tasks:

- [ ] Define the target variable.
- [ ] Define input features.
- [ ] Split data into train and test sets.
- [ ] Apply scaling only when needed.
- [ ] Train at least five appropriate models.
- [ ] Compare model performance.
- [ ] Use suitable metrics.
- [ ] Explain the selected model.
- [ ] Save the trained model to `models/model.pkl`.
- [ ] Save the scaler to `models/scaler.pkl` if used.

Possible regression metrics:

- MAE
- MSE
- RMSE
- R²

Possible model families:

- Linear Regression
- Ridge
- Lasso
- Decision Tree
- Random Forest
- Gradient Boosting
- XGBoost, only if installed and justified

Do not claim that a model is best without metric evidence.

---

### 5.7 `07_prediction_demo.ipynb`

Purpose:

- Load saved model files.
- Run predictions.
- Demonstrate the final machine learning workflow.

Required tasks:

- [ ] Load `models/model.pkl`.
- [ ] Load `models/scaler.pkl` if needed.
- [ ] Reuse the same feature order as training.
- [ ] Validate prediction input.
- [ ] Generate example predictions.
- [ ] Compare predictions with actual values when possible.
- [ ] Handle missing model files clearly.
- [ ] Explain how the notebook connects to the application.

---

## 6. SQL Requirements

### `01_create_tables.sql`

Must include:

- table definitions
- primary keys
- correct PostgreSQL data types
- constraints when appropriate

### `02_import_data.sql`

Must include or document:

- CSV import process
- column mapping
- import validation
- failed-row handling

### `03_views.sql`

Use views for:

- reusable filtered datasets
- cleaned reporting views
- common analysis outputs

### `04_aggregation.sql`

Include analysis queries such as:

- average temperature by year
- average temperature by country
- average temperature by city
- temperature by decade
- monthly temperature patterns

### `05_indexes.sql`

Create indexes only where useful, such as:

- date fields
- country fields
- city fields
- join keys
- frequently filtered columns

Do not add unnecessary indexes.

---

## 7. Application Requirements

The `app/` folder contains the web application.

### `streamlit_app.py`

Responsibilities:

- application entry point
- page configuration
- navigation
- overview dashboard
- high-level project information

### `api.py`

Responsibilities:

- FastAPI entry point
- prediction endpoints
- data endpoints
- health-check endpoint
- input validation
- error handling

Suggested health endpoint:

```text
GET /health
```

Suggested prediction endpoint:

```text
POST /predict
```

Actual routes must be based on the existing project requirements.

### `utils/`

Contains reusable helper code such as:

- file loading
- model loading
- chart helpers
- database helpers
- data validation
- configuration helpers

### `pages/`

Contains separate Streamlit pages, for example:

```text
01_Overview.py
02_Data_Exploration.py
03_Visualizations.py
04_Prediction.py
```

Use only names that match the real files.

### `prediction.py`

Responsibilities:

- input transformation
- feature ordering
- scaler application
- model prediction
- prediction result formatting

Prediction logic must not be duplicated between Streamlit and FastAPI.

---

## 8. Models Folder Rules

The `models/` folder stores trained machine learning artifacts.

Expected files:

```text
model.pkl
scaler.pkl
```

Rules:

- Save model and scaler from the same training run.
- Record feature names and order.
- Do not load untrusted pickle files.
- Handle missing model files clearly.
- Retrain when the feature pipeline changes.
- Do not manually edit `.pkl` files.

A metadata file is recommended:

```text
model_metadata.json
```

Suggested contents:

- model type
- training date
- feature names
- target name
- metrics
- dataset version

---

## 9. Reports Folder Rules

The `reports/` folder contains final deliverables.

Expected files:

```text
reports/
├── tai-lieu-du-an-nhom-1.docx
├── slide-du-an-nhom-1.pptx
└── images/
```

The report and presentation must reflect the real results from:

- notebooks
- SQL analysis
- machine learning metrics
- application screenshots

Do not invent figures, model scores, or conclusions.

Save exported charts and screenshots to:

```text
reports/images/
```

---

## 10. Team Responsibilities

### Member 1 — Project Leader and Data Understanding

Primary work:

```text
notebooks/01_data_understanding.ipynb
README.md
Task_Tracker.xlsx
Project integration
```

Responsibilities:

- manage GitHub
- review work
- integrate branches
- track team tasks
- maintain documentation
- verify final workflow

### Member 2 — PostgreSQL Pipeline

Primary work:

```text
notebooks/02_postgresql_pipeline.ipynb
sql/
```

Responsibilities:

- database schema
- PostgreSQL connection
- imports
- joins
- aggregations
- views and indexes

### Member 3 — Data Cleaning

Primary work:

```text
notebooks/03_data_cleaning.ipynb
data/processed/
```

Responsibilities:

- missing values
- duplicates
- outliers
- data type conversion
- cleaned data export

### Member 4 — EDA and Visualization

Primary work:

```text
notebooks/04_eda_visualization.ipynb
reports/images/
```

Responsibilities:

- analysis
- visualizations
- chart explanations
- report images

### Member 5 — Feature Engineering and Machine Learning

Primary work:

```text
notebooks/05_feature_engineering.ipynb
notebooks/06_machine_learning.ipynb
notebooks/07_prediction_demo.ipynb
models/
```

Responsibilities:

- feature creation
- correlation analysis
- model training
- model comparison
- prediction demo
- saved model artifacts

The project leader may redistribute tasks when workload is uneven.

---

## 11. Agent Working Rules

Before modifying the project, the Agent must:

1. Read this `AGENTS.md` file completely.
2. Inspect the actual workspace.
3. Read `README.md`.
4. Read `Task_Tracker.xlsx` when task ownership matters.
5. Inspect the relevant notebook, SQL, or application files.
6. Check Git status and current branch.
7. Identify existing work before creating new files.
8. Use only actual dataset columns.
9. Propose the change before making large edits.
10. Modify only files related to the requested task.

The Agent must never:

- invent dataset columns
- invent model results
- invent database tables
- expose passwords
- overwrite raw data
- delete working code without explanation
- modify unrelated files
- silently change the project structure
- claim that code was tested when it was not tested

---

## 12. Coding Rules

### Python

- Use clear function and variable names.
- Use type hints where useful.
- Add docstrings to reusable functions.
- Handle errors clearly.
- Use `pathlib.Path` where practical.
- Avoid duplicated logic.
- Move reusable logic into `app/utils/` when it is shared by the application.
- Keep notebook-specific exploration inside notebooks.

### File paths

Prefer paths relative to the project root.

Example:

```python
from pathlib import Path

PROJECT_ROOT = Path.cwd()
DATA_RAW_DIR = PROJECT_ROOT / "data" / "raw"
DATA_PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
MODELS_DIR = PROJECT_ROOT / "models"
REPORT_IMAGES_DIR = PROJECT_ROOT / "reports" / "images"
```

The Agent must first verify the current working directory before using this pattern.

### Environment variables

Database credentials and secrets must be read from environment variables.

Never commit:

```text
.env
database passwords
API keys
private tokens
```

A `.env.example` file may be created when needed.

---

## 13. Git Rules

Recommended branches:

```text
main
feature/data-understanding
feature/postgresql-pipeline
feature/data-cleaning
feature/eda-visualization
feature/feature-engineering
feature/machine-learning
feature/application
feature/documentation
```

Rules:

- Do not work directly on `main` unless instructed.
- Pull latest changes before starting.
- Make small commits.
- Use clear commit messages.
- Review notebook changes carefully.
- Do not commit virtual environments.
- Do not commit cache files.
- Do not commit `.env`.
- Do not commit large temporary outputs.

Example commit messages:

```text
Add initial data understanding notebook
Create PostgreSQL schema and import scripts
Clean missing values and outliers
Add temperature trend visualizations
Create time-based machine learning features
Train and compare regression models
Add Streamlit prediction page
Update final project documentation
```

---

## 14. Project Checklist

### Setup

- [ ] Confirm the real project root.
- [ ] Confirm all required folders exist.
- [ ] Check `requirements.txt`.
- [ ] Check `README.md`.
- [ ] Check `Task_Tracker.xlsx`.
- [ ] Identify real CSV files.
- [ ] Confirm Python environment.
- [ ] Confirm PostgreSQL environment.

### Data Understanding

- [ ] Complete notebook 01.
- [ ] Document shape and columns.
- [ ] Check missing values.
- [ ] Check duplicates.
- [ ] Write initial observations.

### PostgreSQL

- [ ] Complete notebook 02.
- [ ] Create tables.
- [ ] Import data.
- [ ] Create views.
- [ ] Add aggregation queries.
- [ ] Add useful indexes.
- [ ] Validate row counts.

### Data Cleaning

- [ ] Complete notebook 03.
- [ ] Handle missing values.
- [ ] Handle duplicates.
- [ ] Handle outliers.
- [ ] Save cleaned data.
- [ ] Document row-count changes.

### EDA

- [ ] Complete notebook 04.
- [ ] Create meaningful charts.
- [ ] Add written insights.
- [ ] Export report images.

### Feature Engineering

- [ ] Complete notebook 05.
- [ ] Create meaningful features.
- [ ] Analyze correlations.
- [ ] Avoid leakage.
- [ ] Save feature dataset.

### Machine Learning

- [ ] Complete notebook 06.
- [ ] Prepare train/test datasets.
- [ ] Train at least five models.
- [ ] Compare metrics.
- [ ] Select best model.
- [ ] Save model.
- [ ] Save scaler if needed.

### Prediction Demo

- [ ] Complete notebook 07.
- [ ] Load model artifacts.
- [ ] Validate feature order.
- [ ] Generate predictions.
- [ ] Explain results.

### Application

- [ ] Create or complete Streamlit app.
- [ ] Create or complete FastAPI API.
- [ ] Add prediction logic.
- [ ] Add input validation.
- [ ] Connect model artifacts.
- [ ] Test application flow.

### Reports

- [ ] Complete Word report.
- [ ] Complete PowerPoint presentation.
- [ ] Add charts and screenshots.
- [ ] Use real model results.
- [ ] Add final conclusions.

### Final Validation

- [ ] All notebooks run from top to bottom.
- [ ] SQL scripts run in order.
- [ ] Application starts successfully.
- [ ] Model files load successfully.
- [ ] README instructions are correct.
- [ ] No secrets are committed.
- [ ] Git repository is ready for submission.

---

## 15. Instructions for Every New Agent Session

Use this process at the start of each session:

```text
1. Read AGENTS.md.
2. Inspect the entire workspace.
3. Read README.md.
4. Check Task_Tracker.xlsx when relevant.
5. Check Git status and current branch.
6. Inspect files related to the requested task.
7. Summarize what already exists.
8. Identify missing or broken parts.
9. Propose one small next step.
10. Do not change unrelated files.
```

Recommended first prompt:

```text
Read AGENTS.md and inspect the entire current workspace.

Do not modify anything yet.

Report:
1. The actual folder and file structure
2. The real CSV datasets found
3. The current state of notebooks 01 to 07
4. The current state of SQL scripts
5. The current state of the Streamlit and FastAPI application
6. The trained model files currently available
7. Missing dependencies or configuration
8. Git branch and uncommitted changes
9. The safest next development task

Use only information found in the workspace.
Do not invent filenames, columns, tables, model metrics, or API routes.
```

---

## 16. Definition of Done

A task is complete only when:

- It uses the real project files.
- It works with the real dataset.
- It does not break existing code.
- Its outputs are validated.
- Its errors are handled.
- It does not expose secrets.
- Its documentation is updated when necessary.
- Only requested files are changed.
- The Agent reports how the result was tested.

---

## 17. Required Agent Response Format

After completing a task, the Agent must respond using:

```text
Summary:
- What was completed

Files changed:
- Exact file paths

Validation:
- Commands, notebook cells, or checks performed

Results:
- Important outputs or metrics

Remaining issues:
- Known problems or unfinished work

Next recommended step:
- One clear next action
```
