# Perceptual Judgments of Video Authenticity: An Examination of Viewing Duration, Confidence, Content, and Strategies
This repository contains the response data and analysis code associated with the manuscript:

Perceptual Judgments of Video Authenticity: An Examination of Viewing Duration, Confidence, Content, and Strategies 

C. Davodi, S. Barrington, H. Farid and E. A. Cooper

APAI Workshop at CVPR, 2026

Please cite this manuscript if you use the associated data.

The videos used in this study can be found at https://doi.org/10.5281/zenodo.19463141

# Response data
Response data are contained in data.csv. Columns are as follows:

| Column | Description |
|--------|-------------|
| `participant_id` | Unique identifier for each respondent |
| `column` | Original raw trial column name from the wide Qualtrics CSV such as `RF_1_Apple_0` |
| `question_type` | Question family parsed from the raw column name; here `RF` means the real-vs-AI judgment item |
| `model_code` | Coded model identity parsed from the raw column name: `Apple` = `Bytedance`, `Banana` = `Real`, `Pear` = `Sora`, or `Kiwi` = `Veo`|
| `model_label` | Human-readable model name mapped from `model_code` |
| `is_real` | Boolean indicating whether the stimulus is truly real content |
| `duration_code` | Coded duration parsed from the raw column name: `0`, `1`, `2`, `3`, or `4` |
| `duration_label` | Human-readable duration mapped from `duration_code`: `0s`, `2s`, `4s`, `6s`, or `8s` |
| `stimulus` | Stimulus ID parsed from the raw column name; ranges from `1` to `24` |
| `response` | Participant's raw response to the real-vs-AI judgment question |
| `answered` | Boolean indicating whether the participant answered that trial |
| `is_correct` | Boolean indicating whether the response matches the true status of the stimulus |
| `confidence_raw` | Raw confidence response from the matching `CR_...` column |
| `confidence` | Numeric confidence value parsed from `confidence_raw` on a `0` to `3` scale |
| `is_correct_numeric` | Numeric version of correctness used for analysis: `1.0` for correct and `0.0` for incorrect |
| `age` | Participant age in years |
| `gender` | Participant gender |
| `device_type` | Participant device type |
| `is_mobile` | Boolean indicator derived from `device_type` for whether the device was mobile |
| `time_taken` | Time taken to complete the survey in seconds |
| `Strat 1` | Overall decision strategy |
| `Strat 2` | Specific features/cues attended to |
| `Strat 3` | Cues used when confidence was especially high for AI judgments |

Each row in the filtered analysis dataset represents a single participant-trial observation. Trial-level variables such as `stimulus`, `model_code`, `duration_label`, `response`, and `confidence` vary across rows within a participant. Participant-level variables such as `age`, `gender`, `device_type`, and `time_taken` are global to the respondent and therefore repeat across all rows for that participant. Likewise, the open-ended `Strat 1`, `Strat 2`, and `Strat 3` responses are survey-level variables: they are provided once per participant for the overall survey, not once per stimulus.

Note that duration refers to the presentation duration of an individual stimulus (0s, 2s, 4s, 6s, 8s), whereas survey Duration (in seconds) refers to the participant’s total time spent completing the full survey.

# Analysis code
The Matlab script called "run_analyses" can be used to reproduce all tables and figures. This script optionally calls "fit_model" to run the logistic regression models reported in the paper. All analyses were performed in Matlab 2025b, and require the Statistics and Machine Learning Toolbox and the Text Analytics Toolbox.
