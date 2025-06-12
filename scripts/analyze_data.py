import json
import re
from collections import Counter, defaultdict
from typing import Set, List, Dict
import os

def clean_text(text: str) -> str:
    """Clean and normalize text for analysis."""
    # Convert to lowercase and remove special characters
    text = re.sub(r'[^\w\s]', ' ', text.lower())
    # Remove extra whitespace
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def extract_keywords(text: str, min_length: int = 3, max_length: int = 15) -> Set[str]:
    """Extract meaningful keywords from text."""
    words = clean_text(text).split()
    
    # Filter out common stop words
    stop_words = {
        'the', 'is', 'at', 'which', 'on', 'and', 'a', 'an', 'as', 'are', 'was', 'were',
        'been', 'be', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
        'should', 'may', 'might', 'can', 'must', 'shall', 'to', 'of', 'in', 'for', 'with',
        'by', 'from', 'up', 'about', 'into', 'through', 'during', 'before', 'after',
        'above', 'below', 'between', 'among', 'around', 'under', 'over', 'out', 'off',
        'down', 'upon', 'within', 'without', 'across', 'against', 'along', 'amid',
        'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she', 'it', 'we', 'they',
        'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his', 'its', 'our', 'their',
        'also', 'but', 'or', 'so', 'than', 'too', 'very', 'just', 'now', 'then', 'here',
        'there', 'when', 'where', 'why', 'how', 'what', 'who', 'whom', 'whose', 'which',
        'only', 'such', 'same', 'other', 'another', 'each', 'every', 'all', 'both',
        'either', 'neither', 'some', 'any', 'many', 'much', 'few', 'little', 'more',
        'most', 'less', 'least', 'enough', 'several', 'own', 'used', 'make', 'made',
        'take', 'taken', 'give', 'given', 'get', 'got', 'come', 'came', 'go', 'went',
        'know', 'knew', 'known', 'think', 'thought', 'see', 'saw', 'seen', 'look',
        'looked', 'find', 'found', 'want', 'wanted', 'need', 'needed', 'try', 'tried',
        'ask', 'asked', 'tell', 'told', 'say', 'said', 'call', 'called', 'put', 'let',
        'help', 'work', 'worked', 'show', 'showed', 'shown', 'keep', 'kept', 'start',
        'started', 'turn', 'turned', 'move', 'moved', 'play', 'played', 'run', 'ran',
        'walk', 'walked', 'talk', 'talked', 'bring', 'brought', 'write', 'wrote',
        'written', 'sit', 'sat', 'stand', 'stood', 'hear', 'heard', 'leave', 'left',
        'feel', 'felt', 'seem', 'seemed', 'become', 'became', 'follow', 'followed',
        'remain', 'remained', 'include', 'included', 'continue', 'continued', 'set',
        'place', 'placed', 'end', 'ended', 'believe', 'believed', 'hold', 'held',
        'happen', 'happened', 'carry', 'carried', 'lead', 'led', 'meet', 'met',
        'create', 'created', 'live', 'lived', 'cause', 'caused', 'open', 'opened',
        'add', 'added', 'read', 'change', 'changed', 'close', 'closed', 'remember',
        'remembered', 'lose', 'lost', 'win', 'won', 'send', 'sent', 'receive',
        'received', 'decide', 'decided', 'build', 'built', 'break', 'broke', 'broken',
        'spend', 'spent', 'cut', 'learn', 'learned', 'control', 'controlled',
        'develop', 'developed', 'face', 'faced', 'reach', 'reached', 'understand',
        'understood', 'watch', 'watched', 'stop', 'stopped', 'cover', 'covered',
        'buy', 'bought', 'raise', 'raised', 'kill', 'killed', 'pick', 'picked',
        'sell', 'sold', 'require', 'required', 'report', 'reported', 'fall', 'fell',
        'fallen', 'die', 'died', 'pull', 'pulled', 'accept', 'accepted', 'relate',
        'related', 'allow', 'allowed', 'pass', 'passed', 'apply', 'applied', 'appear',
        'appeared', 'suggest', 'suggested', 'offer', 'offered', 'consider',
        'considered', 'present', 'presented', 'involve', 'involved', 'express',
        'expressed', 'serve', 'served', 'produce', 'produced', 'expect', 'expected',
        'explain', 'explained', 'stay', 'stayed', 'exist', 'existed', 'occur',
        'occurred', 'reduce', 'reduced', 'increase', 'increased', 'contain',
        'contained', 'achieve', 'achieved', 'improve', 'improved', 'return',
        'returned', 'treat', 'treated', 'form', 'formed', 'base', 'based',
        'point', 'pointed', 'result', 'resulted', 'note', 'noted', 'direct',
        'directed', 'identify', 'identified', 'force', 'forced', 'support',
        'supported', 'establish', 'established', 'speak', 'spoke', 'spoken',
        'act', 'acted', 'share', 'shared', 'affect', 'affected', 'choose', 'chose',
        'chosen', 'compare', 'compared', 'operate', 'operated', 'gain', 'gained',
        'maintain', 'maintained', 'argue', 'argued', 'claim', 'claimed', 'draw',
        'drew', 'drawn', 'agree', 'agreed', 'fail', 'failed', 'discuss',
        'discussed', 'assume', 'assumed', 'manage', 'managed', 'tend', 'tended',
        'indicate', 'indicated', 'occur', 'save', 'saved', 'join', 'joined',
        'avoid', 'avoided', 'enter', 'entered', 'answer', 'answered', 'plan',
        'planned', 'complete', 'completed', 'determine', 'determined', 'sell',
        'describe', 'described', 'recognize', 'recognized', 'enjoy', 'enjoyed',
        'attend', 'attended', 'check', 'checked', 'remove', 'removed', 'drop',
        'dropped', 'visit', 'visited', 'wear', 'wore', 'worn', 'mention',
        'mentioned', 'deliver', 'delivered', 'grow', 'grew', 'grown', 'announce',
        'announced', 'win', 'matter', 'mattered', 'introduce', 'introduced',
        'prepare', 'prepared', 'cook', 'cooked', 'catch', 'caught', 'protect',
        'protected', 'train', 'trained', 'sort', 'sorted', 'access', 'accessed',
        'address', 'addressed', 'recommend', 'recommended', 'handle', 'handled',
        'bear', 'bore', 'born', 'trade', 'traded', 'regard', 'regarded',
        'measure', 'measured', 'source', 'sourced', 'break', 'test', 'tested',
        'match', 'matched', 'ignore', 'ignored', 'connect', 'connected', 'extend',
        'extended', 'review', 'reviewed', 'remember', 'design', 'designed',
        'repeat', 'repeated', 'push', 'pushed', 'seek', 'sought', 'miss', 'missed',
        'attack', 'attacked', 'comment', 'commented', 'press', 'pressed',
        'replace', 'replaced', 'intend', 'intended', 'wish', 'wished', 'confirm',
        'confirmed', 'order', 'ordered', 'promise', 'promised', 'beat', 'beaten',
        'release', 'released', 'collect', 'collected', 'demand', 'demanded',
        'discover', 'discovered', 'wonder', 'wondered', 'contain', 'supply',
        'supplied', 'appreciate', 'appreciated', 'knock', 'knocked', 'warn',
        'warned', 'declare', 'declared', 'rely', 'relied', 'reveal', 'revealed',
        'surround', 'surrounded', 'progress', 'progressed', 'examine', 'examined',
        'search', 'searched', 'walk', 'notice', 'noticed', 'store', 'stored',
        'submit', 'submitted', 'prefer', 'preferred', 'balance', 'balanced',
        'steal', 'stole', 'stolen', 'refuse', 'refused', 'suspect', 'suspected',
        'trust', 'trusted', 'record', 'recorded', 'score', 'scored', 'exercise',
        'exercised', 'organize', 'organized', 'realise', 'realised', 'realize',
        'realized', 'encourage', 'encouraged', 'engage', 'engaged', 'guarantee',
        'guaranteed', 'refer', 'referred', 'ensure', 'ensured', 'attempt',
        'attempted', 'commit', 'committed', 'overcome', 'overcame', 'appeal',
        'appealed', 'retire', 'retired', 'elect', 'elected', 'attract',
        'attracted', 'arise', 'arose', 'arisen', 'charge', 'charged', 'advance',
        'advanced', 'mount', 'mounted', 'escape', 'escaped', 'celebrate',
        'celebrated', 'convince', 'convinced', 'threaten', 'threatened', 'repair',
        'repaired', 'purchase', 'purchased', 'frame', 'framed', 'struggle',
        'struggled', 'recall', 'recalled', 'dance', 'danced', 'recover',
        'recovered', 'respond', 'responded', 'settle', 'settled', 'debate',
        'debated', 'dismiss', 'dismissed', 'stretch', 'stretched', 'lock',
        'locked', 'march', 'marched', 'deliver', 'educate', 'educated', 'track',
        'tracked', 'challenge', 'challenged', 'spread', 'employ', 'employed',
        'grab', 'grabbed', 'divide', 'divided', 'print', 'printed', 'transform',
        'transformed', 'unite', 'united', 'slide', 'slid', 'shut', 'compete',
        'competed', 'replace', 'blame', 'blamed', 'lift', 'lifted', 'seat',
        'seated', 'pack', 'packed', 'hunt', 'hunted', 'vote', 'voted', 'deliver',
        'paint', 'painted', 'explore', 'explored', 'shake', 'shook', 'shaken',
        'joke', 'joked', 'assist', 'assisted', 'invite', 'invited', 'climb',
        'climbed', 'label', 'labeled', 'risk', 'risked', 'launch', 'launched',
        'permit', 'permitted', 'promote', 'promoted', 'adopt', 'adopted',
        'feature', 'featured', 'award', 'awarded', 'gather', 'gathered',
        'contract', 'contracted', 'campaign', 'campaigned', 'finance', 'financed',
        'borrow', 'borrowed', 'possess', 'possessed', 'install', 'installed',
        'bother', 'bothered', 'hide', 'hid', 'hidden', 'wave', 'waved', 'fund',
        'funded', 'escape', 'monitor', 'monitored', 'mark', 'marked', 'swing',
        'swung', 'behave', 'behaved', 'communicate', 'communicated', 'bind',
        'bound', 'negotiate', 'negotiated', 'deliver', 'honor', 'honored',
        'locate', 'located', 'switch', 'switched', 'approve', 'approved',
        'surround', 'limit', 'limited', 'reflect', 'reflected', 'represent',
        'represented', 'link', 'linked', 'focus', 'focused', 'detail', 'detailed',
        'arrange', 'arranged', 'strike', 'struck', 'stricken', 'tip', 'tipped',
        'guide', 'guided', 'select', 'selected', 'fix', 'fixed', 'stick',
        'stuck', 'demonstrate', 'demonstrated', 'distribute', 'distributed',
        'calculate', 'calculated', 'defend', 'defended', 'copy', 'copied',
        'earn', 'earned', 'function', 'functioned', 'list', 'listed', 'benefit',
        'benefited', 'publish', 'published', 'schedule', 'scheduled', 'judge',
        'judged', 'combine', 'combined', 'research', 'researched', 'expose',
        'exposed', 'generate', 'generated', 'license', 'licensed', 'consist',
        'consisted', 'adapt', 'adapted', 'register', 'registered', 'rule',
        'ruled', 'enable', 'enabled', 'transfer', 'transferred', 'flow',
        'flowed', 'commission', 'commissioned', 'admit', 'admitted', 'compete',
        'compose', 'composed', 'concentrate', 'concentrated', 'integrate',
        'integrated', 'invest', 'invested', 'evaluate', 'evaluated', 'transport',
        'transported', 'conclude', 'concluded', 'experiment', 'experimented',
        'retire', 'retain', 'retained', 'acquire', 'acquired', 'recommend',
        'confuse', 'confused', 'modify', 'modified', 'ignore', 'consume',
        'consumed', 'cite', 'cited', 'anticipate', 'anticipated', 'rank',
        'ranked', 'estimate', 'estimated', 'submit', 'export', 'exported',
        'rub', 'rubbed', 'process', 'processed', 'import', 'imported', 'cancel',
        'cancelled', 'conduct', 'conducted', 'stress', 'stressed', 'murder',
        'murdered', 'derive', 'derived', 'demonstrate', 'deserve', 'deserved',
        'justify', 'justified', 'edit', 'edited', 'execute', 'executed',
        'distinguish', 'distinguished', 'enhance', 'enhanced', 'favor',
        'favored', 'implement', 'implemented', 'oppose', 'opposed', 'qualify',
        'qualified', 'regulate', 'regulated', 'resolve', 'resolved', 'utilize',
        'utilized', 'enforce', 'enforced', 'vary', 'varied', 'weigh', 'weighed',
        'maintain', 'exchange', 'exchanged', 'occupy', 'occupied', 'schedule',
        'contribute', 'contributed', 'participate', 'participated', 'construct',
        'constructed', 'convey', 'conveyed', 'abandon', 'abandoned', 'sustain',
        'sustained', 'manufacture', 'manufactured', 'dominate', 'dominated',
        'reinforce', 'reinforced', 'substitute', 'substituted', 'accompany',
        'accompanied', 'convert', 'converted', 'eliminate', 'eliminated', 'omit',
        'omitted', 'restrain', 'restrained', 'violate', 'violated', 'compile',
        'compiled', 'constitute', 'constituted', 'coordinate', 'coordinated',
        'decline', 'declined', 'depict', 'depicted', 'diverse', 'diversed',
        'exclude', 'excluded', 'extract', 'extracted', 'incorporate',
        'incorporated', 'perceive', 'perceived', 'prohibit', 'prohibited',
        'submit', 'sustain', 'transmit', 'transmitted', 'accumulate',
        'accumulated', 'assert', 'asserted', 'commence', 'commenced',
        'emphasize', 'emphasized', 'equip', 'equipped', 'insert', 'inserted',
        'inspect', 'inspected', 'migrate', 'migrated', 'overcome', 'proceed',
        'proceeded', 'prosecute', 'prosecuted', 'restore', 'restored', 'revise',
        'revised', 'simulate', 'simulated', 'specify', 'specified', 'allocate',
        'allocated', 'coincide', 'coincided', 'collapse', 'collapsed',
        'compile', 'complement', 'complemented', 'comprehensive', 'compute',
        'computed', 'conceive', 'conceived', 'confine', 'confined', 'consult',
        'consulted', 'consume', 'contemplate', 'contemplated', 'contradict',
        'contradicted', 'cooperate', 'cooperated', 'correspond', 'corresponded',
        'deduce', 'deduced', 'distort', 'distorted', 'equate', 'equated',
        'fluctuate', 'fluctuated', 'furthermore', 'impose', 'imposed',
        'incline', 'inclined', 'inhibit', 'inhibited', 'invoke', 'invoked',
        'manipulate', 'manipulated', 'overlap', 'overlapped', 'predominant',
        'predominated', 'preliminary', 'preliminary', 'protocol', 'random',
        'randomized', 'restrain', 'rigid', 'sequence', 'sequenced', 'sole',
        'subsequent', 'theme', 'underlie', 'underlying', 'whereas', 'whereby',
        'distinct', 'federal', 'image', 'instance', 'interpret', 'interpreted',
        'negative', 'period', 'policy', 'positive', 'previous', 'primary',
        'principle', 'procedure', 'project', 'projected', 'proportion',
        'significant', 'structure', 'structured', 'theory', 'variable',
        'version', 'achieve', 'adequate', 'annual', 'apparent', 'approximate',
        'attitude', 'attribute', 'attributed', 'authority', 'available',
        'benefit', 'concept', 'consistent', 'constant', 'constitute', 'context',
        'contract', 'create', 'data', 'definition', 'derive', 'distribute',
        'economy', 'element', 'environment', 'establish', 'estimate', 'evident',
        'export', 'factor', 'final', 'formula', 'function', 'identify',
        'income', 'individual', 'interpret', 'involve', 'issue', 'labor',
        'legal', 'legislate', 'legislated', 'major', 'method', 'occur',
        'percent', 'percent', 'period', 'policy', 'principle', 'proceed',
        'process', 'require', 'research', 'respond', 'role', 'section',
        'sector', 'significant', 'similar', 'source', 'specific', 'structure',
        'theory', 'vary', 'area', 'assessment', 'available', 'commission',
        'community', 'complex', 'computer', 'conclusion', 'conduct',
        'conference', 'contract', 'design', 'economy', 'environment',
        'equipment', 'estimate', 'evidence', 'export', 'factor', 'financial',
        'income', 'indicate', 'individual', 'investment', 'issue', 'item',
        'journal', 'labor', 'legal', 'legislation', 'major', 'method',
        'normal', 'obtain', 'obtained', 'occur', 'percent', 'period',
        'physical', 'policy', 'previous', 'primary', 'principle', 'procedure',
        'process', 'purchase', 'range', 'region', 'regulation', 'relevant',
        'require', 'research', 'resource', 'respond', 'restrict', 'restricted',
        'role', 'section', 'sector', 'select', 'significant', 'similar',
        'site', 'source', 'specific', 'structure', 'survey', 'surveyed',
        'text', 'tradition', 'traditional', 'transfer', 'trend', 'vary',
        'adult', 'affect', 'analysis', 'approach', 'area', 'aspect',
        'assistance', 'available', 'benefit', 'category', 'chapter', 'commission',
        'committee', 'common', 'communication', 'community', 'complex',
        'computer', 'concept', 'conclusion', 'condition', 'conference',
        'congress', 'consistent', 'constitutional', 'consumer', 'contract',
        'culture', 'data', 'debate', 'decade', 'design', 'despite', 'dimension',
        'domestic', 'economy', 'element', 'emphasis', 'energy', 'enforcement',
        'environment', 'equipment', 'establish', 'ethnic', 'evaluation',
        'evidence', 'export', 'external', 'factor', 'feature', 'federal',
        'final', 'financial', 'focus', 'formula', 'framework', 'function',
        'funding', 'gender', 'global', 'goal', 'grade', 'grant', 'hypothesis',
        'identity', 'image', 'impact', 'implementation', 'implication', 'import',
        'income', 'index', 'individual', 'initial', 'initiative', 'input',
        'instance', 'institute', 'instruction', 'integration', 'intelligence',
        'internal', 'interpretation', 'intervention', 'investigation', 'investment',
        'issue', 'item', 'job', 'journal', 'label', 'labor', 'layer',
        'lecture', 'legal', 'legislation', 'length', 'location', 'logic',
        'maintenance', 'major', 'margin', 'maximum', 'mechanism', 'media',
        'medical', 'medium', 'method', 'migration', 'military', 'minimum',
        'ministry', 'minor', 'mode', 'modification', 'network', 'normal',
        'notion', 'objective', 'obtain', 'obvious', 'occupation', 'occur',
        'option', 'orientation', 'outcome', 'output', 'overall', 'parallel',
        'parameter', 'participation', 'partner', 'partnership', 'percent',
        'period', 'perspective', 'phase', 'phenomenon', 'philosophy', 'physical',
        'plus', 'policy', 'portion', 'position', 'positive', 'potential',
        'practitioner', 'preceding', 'precise', 'predict', 'predicted',
        'preliminary', 'previous', 'primary', 'prime', 'principal', 'principle',
        'prior', 'priority', 'procedure', 'process', 'professional', 'project',
        'proportion', 'publication', 'purchase', 'pursue', 'pursued', 'quote',
        'quoted', 'range', 'ratio', 'rational', 'reaction', 'regime',
        'region', 'register', 'regulation', 'reject', 'rejected', 'relax',
        'relaxed', 'release', 'relevant', 'reluctance', 'rely', 'remove',
        'require', 'research', 'reserve', 'reserved', 'resolve', 'resource',
        'respond', 'response', 'restrict', 'retain', 'reveal', 'revenue',
        'reverse', 'reversed', 'revolution', 'role', 'route', 'scenario',
        'schedule', 'scheme', 'scope', 'section', 'sector', 'security',
        'seek', 'select', 'series', 'sex', 'shift', 'shifted', 'significant',
        'similar', 'site', 'source', 'specific', 'sphere', 'stable', 'statistic',
        'status', 'straightforward', 'strategy', 'stress', 'structure', 'style',
        'submit', 'subsequent', 'subsidy', 'substitute', 'successor', 'sufficient',
        'summary', 'supplement', 'supplemented', 'survey', 'survive', 'survived',
        'suspend', 'suspended', 'symbol', 'tape', 'target', 'targeted', 'task',
        'team', 'technical', 'technique', 'technology', 'temporary', 'tense',
        'terminal', 'text', 'theme', 'theory', 'thereby', 'thesis', 'topic',
        'trace', 'traced', 'track', 'tradition', 'transfer', 'transformation',
        'transition', 'transport', 'trend', 'trigger', 'triggered', 'ultimate',
        'undergo', 'underwent', 'undergone', 'underlie', 'undertake',
        'undertook', 'undertaken', 'uniform', 'unify', 'unified', 'unique',
        'unity', 'university', 'update', 'updated', 'utility', 'utilize',
        'valid', 'vary', 'vehicle', 'version', 'via', 'video', 'violate',
        'virtual', 'visible', 'vision', 'visual', 'volume', 'voluntary',
        'welfare', 'whereas', 'whereby', 'widespread'
    }
    
    # Extract keywords
    keywords = set()
    for word in words:
        if (min_length <= len(word) <= max_length and 
            word not in stop_words and 
            word.isalpha()):
            keywords.add(word)
    
    # Also extract meaningful multi-word phrases (2-3 words)
    for i in range(len(words) - 1):
        phrase = ' '.join(words[i:i+2])
        if (min_length <= len(phrase) <= max_length and 
            all(w not in stop_words for w in words[i:i+2])):
            keywords.add(phrase)
    
    for i in range(len(words) - 2):
        phrase = ' '.join(words[i:i+3])
        if (min_length <= len(phrase) <= max_length and 
            all(w not in stop_words for w in words[i:i+3])):
            keywords.add(phrase)
    
    return keywords

def analyze_jsonl_file(filepath: str) -> Dict:
    """Analyze a JSONL file and extract keyword statistics."""
    print(f"Analyzing {filepath}...")
    
    if not os.path.exists(filepath):
        print(f"  File not found: {filepath}")
        return {}
    
    title_keywords = Counter()
    question_keywords = Counter()
    passage_keywords = Counter()
    all_keywords = Counter()
    
    line_count = 0
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                if line_num % 1000 == 0:
                    print(f"  Processed {line_num} lines...")
                
                try:
                    entry = json.loads(line.strip())
                    line_count += 1
                    
                    title = entry.get('title', '')
                    question = entry.get('question', '')
                    passage = entry.get('passage', '')
                    
                    # Extract keywords from each field
                    title_kw = extract_keywords(title)
                    question_kw = extract_keywords(question)
                    passage_kw = extract_keywords(passage)
                    
                    # Update counters
                    title_keywords.update(title_kw)
                    question_keywords.update(question_kw)
                    passage_keywords.update(passage_kw)
                    all_keywords.update(title_kw | question_kw | passage_kw)
                    
                except json.JSONDecodeError as e:
                    print(f"  Error parsing line {line_num}: {e}")
                    continue
                    
                # Limit processing for very large files
                if line_count >= 10000:
                    print(f"  Stopping at {line_count} lines for performance...")
                    break
                    
    except Exception as e:
        print(f"  Error reading file: {e}")
        return {}
    
    print(f"  Processed {line_count} entries")
    
    return {
        'title_keywords': title_keywords,
        'question_keywords': question_keywords,
        'passage_keywords': passage_keywords,
        'all_keywords': all_keywords,
        'total_entries': line_count
    }

def generate_tag_categories(analysis_results: Dict) -> Dict[str, List[str]]:
    """Generate tag categories based on keyword analysis."""
    print("\nGenerating tag categories...")
    
    all_keywords = analysis_results.get('all_keywords', Counter())
    
    # Get the most common keywords
    top_keywords = [word for word, count in all_keywords.most_common(1000) if count >= 3]
    
    # Group keywords into categories based on domain knowledge and patterns
    categories = defaultdict(list)
    
    # Science and technology
    science_patterns = ['science', 'scientific', 'research', 'study', 'experiment', 'theory', 'hypothesis',
                       'physics', 'chemistry', 'biology', 'medical', 'health', 'disease', 'treatment',
                       'technology', 'computer', 'internet', 'digital', 'software', 'data', 'algorithm',
                       'energy', 'nuclear', 'solar', 'electric', 'power', 'fuel', 'battery',
                       'climate', 'environment', 'carbon', 'emission', 'pollution', 'temperature',
                       'space', 'planet', 'earth', 'moon', 'solar system', 'galaxy', 'universe']
    
    # Politics and government
    politics_patterns = ['government', 'political', 'politics', 'policy', 'law', 'legal', 'court',
                        'president', 'congress', 'senate', 'parliament', 'minister', 'election',
                        'vote', 'democracy', 'republic', 'constitution', 'federal', 'state',
                        'tax', 'taxation', 'budget', 'military', 'war', 'peace', 'treaty']
    
    # Economics and business
    economics_patterns = ['economic', 'economy', 'business', 'company', 'corporation', 'market',
                         'trade', 'commerce', 'finance', 'financial', 'money', 'currency', 'bank',
                         'investment', 'profit', 'revenue', 'cost', 'price', 'inflation', 'recession',
                         'industry', 'manufacturing', 'production', 'employment', 'job', 'work']
    
    # Geography and places
    geography_patterns = ['geography', 'country', 'city', 'state', 'region', 'continent', 'ocean',
                         'river', 'mountain', 'desert', 'forest', 'island', 'lake', 'valley',
                         'north', 'south', 'east', 'west', 'america', 'europe', 'asia', 'africa',
                         'australia', 'antarctica', 'united states', 'canada', 'mexico', 'china',
                         'japan', 'india', 'russia', 'brazil', 'germany', 'france', 'italy',
                         'spain', 'united kingdom', 'england', 'scotland', 'ireland']
    
    # History and culture
    history_patterns = ['history', 'historical', 'ancient', 'medieval', 'modern', 'century',
                       'war', 'battle', 'revolution', 'empire', 'civilization', 'culture',
                       'religion', 'religious', 'christian', 'muslim', 'jewish', 'buddhist',
                       'art', 'music', 'literature', 'philosophy', 'tradition', 'custom']
    
    # Sports and entertainment
    sports_patterns = ['sport', 'sports', 'game', 'team', 'player', 'football', 'basketball',
                      'baseball', 'soccer', 'tennis', 'golf', 'hockey', 'olympic', 'olympics',
                      'movie', 'film', 'television', 'tv', 'book', 'novel', 'author', 'actor',
                      'actress', 'musician', 'singer', 'band', 'album', 'song', 'music']
    
    # Food and cooking
    food_patterns = ['food', 'eat', 'eating', 'cook', 'cooking', 'recipe', 'ingredient',
                    'restaurant', 'kitchen', 'meal', 'breakfast', 'lunch', 'dinner',
                    'fruit', 'vegetable', 'meat', 'fish', 'chicken', 'beef', 'pork',
                    'bread', 'rice', 'pasta', 'cheese', 'milk', 'water', 'drink',
                    'coffee', 'tea', 'wine', 'beer', 'alcohol']
    
    # Animals and nature
    animals_patterns = ['animal', 'animals', 'mammal', 'bird', 'fish', 'insect', 'reptile',
                       'cat', 'dog', 'horse', 'cow', 'pig', 'sheep', 'chicken', 'duck',
                       'lion', 'tiger', 'elephant', 'bear', 'wolf', 'deer', 'rabbit',
                       'tree', 'forest', 'plant', 'flower', 'grass', 'leaf', 'seed',
                       'nature', 'natural', 'wild', 'wildlife', 'ecosystem', 'habitat']
    
    # Transportation
    transport_patterns = ['transport', 'transportation', 'car', 'automobile', 'vehicle',
                         'truck', 'bus', 'train', 'plane', 'airplane', 'ship', 'boat',
                         'bicycle', 'motorcycle', 'road', 'highway', 'street', 'traffic',
                         'airport', 'station', 'port', 'travel', 'journey', 'trip']
    
    # Health and medicine
    health_patterns = ['health', 'medical', 'medicine', 'doctor', 'hospital', 'patient',
                      'disease', 'illness', 'sick', 'healthy', 'treatment', 'therapy',
                      'surgery', 'drug', 'medication', 'vaccine', 'virus', 'bacteria',
                      'cancer', 'heart', 'brain', 'blood', 'bone', 'muscle', 'skin',
                      'eye', 'ear', 'nose', 'mouth', 'tooth', 'teeth']
    
    pattern_groups = {
        'science': science_patterns,
        'politics': politics_patterns,
        'economics': economics_patterns,
        'geography': geography_patterns,
        'history': history_patterns,
        'sports': sports_patterns,
        'food': food_patterns,
        'animals': animals_patterns,
        'transport': transport_patterns,
        'health': health_patterns
    }
    
    # Categorize keywords
    for keyword in top_keywords:
        keyword_lower = keyword.lower()
        categorized = False
        
        for category, patterns in pattern_groups.items():
            if any(pattern in keyword_lower for pattern in patterns):
                categories[category].append(keyword)
                categorized = True
                break
        
        if not categorized:
            categories['general'].append(keyword)
    
    # Convert to regular dict and sort by frequency
    result_categories = {}
    for category, keywords in categories.items():
        # Sort keywords by frequency
        sorted_keywords = sorted(keywords, key=lambda x: all_keywords.get(x, 0), reverse=True)
        result_categories[category] = sorted_keywords[:50]  # Top 50 per category
    
    return result_categories

def main():
    """Main analysis function."""
    print("Data Analysis for Tag Generation")
    print("=" * 40)
    
    # Files to analyze
    files_to_analyze = [
        "data/dev.jsonl",
        "data/train.jsonl"
    ]
    
    all_analysis = {}
    combined_keywords = Counter()
    
    # Analyze each file
    for filepath in files_to_analyze:
        analysis = analyze_jsonl_file(filepath)
        if analysis:
            all_analysis[filepath] = analysis
            combined_keywords.update(analysis.get('all_keywords', Counter()))
    
    if not all_analysis:
        print("No data files found or could be analyzed!")
        return
    
    # Generate tag categories
    categories = generate_tag_categories({'all_keywords': combined_keywords})
    
    # Display results
    print("\n" + "=" * 50)
    print("ANALYSIS RESULTS")
    print("=" * 50)
    
    for filepath, analysis in all_analysis.items():
        print(f"\n{filepath}:")
        print(f"  Total entries: {analysis['total_entries']:,}")
        print(f"  Unique keywords: {len(analysis['all_keywords']):,}")
        print(f"  Top 10 keywords: {[k for k, c in analysis['all_keywords'].most_common(10)]}")
    
    print(f"\nCombined unique keywords: {len(combined_keywords):,}")
    print(f"Top 20 overall keywords: {[k for k, c in combined_keywords.most_common(20)]}")
    
    print("\n" + "=" * 50)
    print("SUGGESTED TAG CATEGORIES")
    print("=" * 50)
    
    for category, keywords in categories.items():
        print(f"\n{category.upper()}:")
        print(f"  Keywords ({len(keywords)}): {keywords[:20]}")  # Show first 20
    
    # Save results to file
    output_file = "tag_analysis_results.json"
    results = {
        'file_analysis': {k: {'total_entries': v['total_entries'], 
                             'top_keywords': dict(v['all_keywords'].most_common(100))} 
                         for k, v in all_analysis.items()},
        'combined_top_keywords': dict(combined_keywords.most_common(200)),
        'suggested_categories': categories
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    
    print(f"\nDetailed results saved to: {output_file}")
    print("\nYou can now use these categories to improve your tag generation!")

if __name__ == "__main__":
    main() 