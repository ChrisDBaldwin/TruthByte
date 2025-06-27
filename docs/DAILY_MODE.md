# TruthByte Daily Mode Documentation

Complete guide to TruthByte's daily mode feature, including deterministic question selection, streak tracking, and performance ranking system.

## Overview

Daily Mode is a new game mode that provides a consistent daily challenge for all users. Every day, all players receive the same 10 questions, creating a shared experience and enabling meaningful comparisons and streak tracking.

## Key Features

### **🎯 Deterministic Question Selection**
- **Same Questions**: All users get identical questions on any given date
- **Date-based Seeding**: Uses cryptographic hash of date for consistent randomization
- **Difficulty Filtering**: Excludes hardest questions (difficulty 5) for better accessibility
- **Quality Pool**: Selects from up to 500 questions for variety

### **🔥 Streak System**
- **Performance Requirement**: ≥70% correct answers required to continue streak
- **Current Streak**: Tracks consecutive days with qualifying performance
- **Best Streak**: Records user's highest streak achievement
- **Streak Eligibility**: Real-time feedback on streak continuation

### **📊 Performance Ranking**
Letter grade system based on percentage correct:
- **S Rank**: 100% correct (Perfect)
- **A Rank**: 80-99% correct (Excellent)
- **B Rank**: 70-79% correct (Good)
- **C Rank**: 60-69% correct (Fair)
- **D Rank**: <60% correct (Needs Improvement)

### **📈 Progress Tracking**
- **Daily Completion**: One attempt per day with permanent results
- **Historical Data**: Complete history of daily performance
- **Score Persistence**: Detailed breakdown of each day's results
- **User Statistics**: Total daily games, current/best streaks

## Technical Architecture

### **Backend Components**

#### New Lambda Functions
- **`fetch_daily_questions`**: Returns deterministic daily questions with user progress
- **`submit_daily_answers`**: Processes submissions and updates streaks

#### Database Schema
- **Users Table**: New table for user profiles and daily progress
- **Daily Progress**: Nested object tracking completion by date
- **Streak Data**: Current and best streak tracking

### **Frontend Components**

#### Game Flow
1. **Mode Selection**: Choose Daily from mode selection screen
2. **Question Retrieval**: Fetch today's 10 questions
3. **Answer Submission**: Complete all questions (no partial completion)
4. **Score Calculation**: Real-time scoring with letter grade
5. **Review Screen**: Display score, rank, and streak information

#### UI Elements
- **Mode Selection Button**: Access daily mode from main menu
- **Daily Review Screen**: Post-completion results with detailed breakdown
- **Streak Indicators**: Visual display of current and best streaks
- **Completion Status**: Visual indication of daily completion

## API Endpoints

### `GET /fetch-daily-questions`
**Purpose**: Get today's daily questions with user progress

**Response Example:**
```json
{
  "questions": [...],
  "date": "2024-01-15",
  "daily_progress": {
    "completed": false,
    "score": 0,
    "answers": []
  },
  "streak_info": {
    "current_streak": 5,
    "best_streak": 12
  },
  "total_questions": 10
}
```

### `POST /submit-daily-answers`
**Purpose**: Submit daily answers and receive score

**Request Example:**
```json
{
  "answers": [
    {
      "question_id": "q001",
      "answer": true,
      "timestamp": 1705324800
    }
  ],
  "date": "2024-01-15"
}
```

**Response Example:**
```json
{
  "success": true,
  "score": {
    "correct_count": 8,
    "total_questions": 10,
    "score_percentage": 80.0,
    "rank": "A",
    "streak_eligible": true
  },
  "streak_info": {
    "current_streak": 6,
    "streak_continued": true
  }
}
```

## User Experience

### **Daily Challenge Flow**
1. User selects Daily Mode from main menu
2. System checks if today's challenge is already completed
3. If not completed, user receives today's 10 questions
4. User answers all questions (must complete all to submit)
5. System calculates score and updates user's streak
6. User sees results screen with score, rank, and streak status

### **Streak Motivation**
- **Visual Feedback**: Prominent streak counters encourage daily participation
- **Performance Threshold**: 70% requirement creates achievable but meaningful goal
- **Historical Tracking**: Best streak record provides long-term motivation
- **Daily Reset**: Fresh opportunity each day regardless of previous performance

### **Fairness and Consistency**
- **No Multiple Attempts**: Once completed, results are final for the day
- **Same Questions**: All users face identical challenge each day
- **Consistent Timing**: Questions available at midnight UTC
- **Fair Difficulty**: Excludes extremely difficult questions

## Implementation Details

### **Deterministic Selection Algorithm**
```python
def get_daily_seed(date_str: str) -> int:
    hash_obj = hashlib.sha256(f"truthbyte-daily-{date_str}".encode())
    return int.from_bytes(hash_obj.digest()[:8], byteorder='big')

def deterministic_sample(items: List[Any], sample_size: int, seed: int) -> List[Any]:
    import random
    rng = random.Random(seed)
    return rng.sample(items, min(sample_size, len(items)))
```

### **Streak Calculation Logic**
```python
def calculate_new_streak(user_id: str, passed_today: bool) -> int:
    if not passed_today:
        return 0
    
    # Get yesterday's completion status
    yesterday = get_yesterday_date()
    user_data = get_user_data(user_id)
    
    yesterday_completed = user_data.get('daily_progress', {}).get(yesterday, {}).get('completed', False)
    yesterday_passed = user_data.get('daily_progress', {}).get(yesterday, {}).get('score', 0) >= 70
    
    if yesterday_completed and yesterday_passed:
        return user_data.get('current_daily_streak', 0) + 1
    else:
        return 1  # Start new streak
```

### **Database Storage Pattern**
```json
{
  "user_id": "uuid",
  "daily_progress": {
    "2024-01-15": {
      "completed": true,
      "score": 80.0,
      "rank": "A",
      "correct_count": 8,
      "total_questions": 10,
      "completed_at": 1705324800
    }
  },
  "current_daily_streak": 6,
  "best_daily_streak": 12
}
```

## Development and Testing

### **Local Testing**
- Use `deploy-single-lambda.ps1` for rapid function deployment
- Test with different dates to verify deterministic behavior
- Check streak calculations with mock user data

### **Quality Assurance**
- Verify same questions appear for all users on same date
- Test streak continuation and reset logic
- Validate score calculation and ranking system
- Ensure completion status prevents duplicate submissions

### **Monitoring**
- Track daily participation rates
- Monitor streak distribution across users
- Analyze question difficulty balance
- Review completion rates and user engagement

## Future Enhancements

### **Potential Features**
- **Leaderboards**: Daily/weekly/monthly rankings
- **Social Features**: Share results, compare with friends
- **Streak Rewards**: Badges or achievements for milestone streaks
- **Analytics**: Personal performance trends and insights
- **Custom Difficulty**: Optional difficulty settings for daily challenges

### **Technical Improvements**
- **Caching**: Cache daily questions for improved performance
- **Notifications**: Daily reminder system
- **Offline Support**: Download questions for offline completion
- **Real-time Updates**: Live streak counters and global participation stats

---

**Last Updated**: Current with daily mode implementation  
**Version**: 1.0.0 