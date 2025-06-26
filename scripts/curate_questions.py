#!/usr/bin/env python3
"""
Curate and improve question quality from BoolQ dataset.

This script:
1. Filters out overly complex/academic questions
2. Fixes grammar and formatting issues
3. Assigns appropriate difficulty levels
4. Converts to new schema format
5. Creates engaging trivia questions suitable for a game

Usage:
    python curate_questions.py --input ../data/dev_with_ids.jsonl --output ../data/curated_questions.jsonl
"""

import json
import argparse
import re
from typing import Dict, List, Any, Optional
import random

class QuestionCurator:
    def __init__(self):
        # Keywords that indicate overly academic/complex questions
        self.academic_keywords = [
            'phylogenetic', 'biochemical', 'molecular', 'genome', 'protein', 'enzyme',
            'hypothesis', 'correlation', 'regression', 'statistical', 'methodology',
            'constitutional', 'jurisdiction', 'plaintiff', 'defendant', 'statute',
            'amendment', 'congress', 'senate', 'federal', 'supreme court'
        ]
        
        # Keywords that indicate good, accessible questions
        self.good_keywords = [
            'movie', 'actor', 'actress', 'film', 'tv show', 'band', 'singer', 'song',
            'country', 'city', 'capital', 'river', 'mountain', 'ocean', 'continent',
            'sport', 'team', 'player', 'game', 'olympics', 'world cup',
            'food', 'restaurant', 'cooking', 'recipe', 'ingredient',
            'animal', 'dog', 'cat', 'bird', 'fish', 'pet',
            'car', 'brand', 'company', 'technology', 'phone', 'computer'
        ]
        
        # Category mapping from tags to single category
        self.category_mapping = {
            'entertainment': ['entertainment', 'music', 'movie', 'tv', 'celebrity'],
            'sports': ['sports', 'olympics', 'football', 'basketball', 'baseball'],
            'geography': ['geography', 'country', 'city', 'capital', 'location'],
            'science': ['science', 'nature', 'animal', 'biology', 'physics'],
            'history': ['history', 'war', 'historical'],
            'food': ['food', 'cooking', 'restaurant', 'drink'],
            'business': ['business', 'company', 'brand', 'technology'],
            'general': ['general', 'misc', 'other']
        }

    def fix_question_grammar(self, question: str) -> str:
        """Fix common grammar issues in questions."""
        # Remove extra spaces
        question = re.sub(r'\s+', ' ', question.strip())
        
        # Fix common patterns
        question = question.replace('does ', 'Does ')
        question = question.replace('is ', 'Is ')
        question = question.replace('can ', 'Can ')
        question = question.replace('will ', 'Will ')
        question = question.replace('has ', 'Has ')
        question = question.replace('have ', 'Have ')
        question = question.replace('are ', 'Are ')
        question = question.replace('was ', 'Was ')
        question = question.replace('were ', 'Were ')
        
        # Ensure question ends with ?
        if not question.endswith('?'):
            question += '?'
            
        # Capitalize first letter
        if question:
            question = question[0].upper() + question[1:]
            
        return question

    def assess_question_difficulty(self, question: str, passage: str) -> int:
        """Assess question difficulty on a scale of 1-5."""
        # Start with base difficulty of 3
        difficulty = 3
        
        # Length-based adjustments
        if len(question.split()) > 15:
            difficulty += 1  # Long questions are harder
        elif len(question.split()) < 8:
            difficulty -= 1  # Short questions are easier
            
        # Academic/technical content
        question_lower = question.lower()
        passage_lower = passage.lower()
        
        academic_count = sum(1 for keyword in self.academic_keywords 
                           if keyword in question_lower or keyword in passage_lower)
        if academic_count > 2:
            difficulty += 2
        elif academic_count > 0:
            difficulty += 1
            
        # Accessible/popular content
        accessible_count = sum(1 for keyword in self.good_keywords 
                             if keyword in question_lower or keyword in passage_lower)
        if accessible_count > 0:
            difficulty -= 1
            
        # Clamp between 1 and 5
        return max(1, min(5, difficulty))

    def determine_category(self, tags: List[str]) -> str:
        """Determine single category from list of tags."""
        if not tags:
            return 'general'
            
        # Count matches for each category
        category_scores = {}
        for category, keywords in self.category_mapping.items():
            score = sum(1 for tag in tags if any(keyword in tag.lower() for keyword in keywords))
            if score > 0:
                category_scores[category] = score
                
        if category_scores:
            # Return category with highest score
            return max(category_scores.items(), key=lambda x: x[1])[0]
        else:
            return 'general'

    def is_question_suitable(self, question_data: Dict[str, Any]) -> bool:
        """Determine if question is suitable for trivia game."""
        question = question_data.get('question', '')
        passage = question_data.get('passage', '')
        
        # Skip if question is too short or malformed
        if len(question.split()) < 4:
            return False
            
        # Skip if question is too long (likely complex)
        if len(question.split()) > 25:
            return False
            
        # Skip if contains too many academic keywords
        question_lower = question.lower()
        academic_count = sum(1 for keyword in self.academic_keywords 
                           if keyword in question_lower)
        if academic_count > 2:
            return False
            
        # Skip if passage is extremely long (indicates complex topic)
        if len(passage.split()) > 200:
            return False
            
        # Skip questions with poor grammar patterns
        if question_lower.startswith('does ') and ' that ' in question_lower:
            # Often poorly formed: "does X that Y"
            return False
            
        return True

    def curate_question(self, question_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Curate a single question."""
        if not self.is_question_suitable(question_data):
            return None
            
        # Extract data
        question = question_data.get('question', '')
        passage = question_data.get('passage', '')
        tags = question_data.get('tags', [])
        
        # Fix grammar
        fixed_question = self.fix_question_grammar(question)
        
        # Determine category and difficulty
        category = self.determine_category(tags)
        difficulty = self.assess_question_difficulty(fixed_question, passage)
        
        # Create curated question
        curated = {
            'id': question_data['id'],
            'question': fixed_question,
            'answer': question_data['answer'],
            'category': category,
            'difficulty': difficulty,
            'tags': tags,  # Keep original tags for reference
            'title': question_data.get('title', ''),
            # Truncate passage for storage efficiency
            'passage': passage[:500] + '...' if len(passage) > 500 else passage
        }
        
        return curated

def main():
    parser = argparse.ArgumentParser(description='Curate questions for better trivia gameplay')
    parser.add_argument('--input', required=True, help='Input JSONL file')
    parser.add_argument('--output', required=True, help='Output JSONL file')
    parser.add_argument('--max-questions', type=int, default=1000, 
                      help='Maximum number of questions to output')
    parser.add_argument('--min-difficulty', type=int, default=1, 
                      help='Minimum difficulty level (1-5)')
    parser.add_argument('--max-difficulty', type=int, default=4, 
                      help='Maximum difficulty level (1-5)')
    
    args = parser.parse_args()
    
    curator = QuestionCurator()
    
    print(f"Loading questions from {args.input}...")
    
    curated_questions = []
    total_processed = 0
    
    with open(args.input, 'r', encoding='utf-8') as f:
        for line in f:
            if not line.strip():
                continue
                
            question_data = json.loads(line.strip())
            total_processed += 1
            
            # Curate the question
            curated = curator.curate_question(question_data)
            
            if curated and args.min_difficulty <= curated['difficulty'] <= args.max_difficulty:
                curated_questions.append(curated)
                
            # Progress update
            if total_processed % 100 == 0:
                print(f"Processed {total_processed} questions, kept {len(curated_questions)}")
                
            # Stop if we have enough questions
            if len(curated_questions) >= args.max_questions:
                break
    
    # Shuffle for variety
    random.shuffle(curated_questions)
    
    # Limit to requested number
    curated_questions = curated_questions[:args.max_questions]
    
    print(f"\nCuration complete!")
    print(f"Total processed: {total_processed}")
    print(f"Questions kept: {len(curated_questions)}")
    print(f"Acceptance rate: {len(curated_questions)/total_processed*100:.1f}%")
    
    # Show category distribution
    categories = {}
    difficulties = {}
    for q in curated_questions:
        cat = q['category']
        diff = q['difficulty']
        categories[cat] = categories.get(cat, 0) + 1
        difficulties[diff] = difficulties.get(diff, 0) + 1
        
    print("\nCategory distribution:")
    for cat, count in sorted(categories.items()):
        print(f"  {cat}: {count}")
        
    print("\nDifficulty distribution:")
    for diff, count in sorted(difficulties.items()):
        print(f"  Level {diff}: {count}")
    
    # Write output
    print(f"\nWriting to {args.output}...")
    with open(args.output, 'w', encoding='utf-8') as f:
        for question in curated_questions:
            f.write(json.dumps(question) + '\n')
    
    print("✅ Done!")
    
    # Show some examples
    print("\nSample curated questions:")
    for i, q in enumerate(curated_questions[:5]):
        print(f"{i+1}. [{q['category']}] {q['question']} (Difficulty: {q['difficulty']})")

if __name__ == '__main__':
    main() 