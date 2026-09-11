puts "Seeding database..."

# Categories
categories = [
  { name: "AI Tech", slug: "ai-tech", description: "Breakthroughs, hardware, research, and the cutting edge of artificial intelligence", icon: "cpu", color: "#6366f1", position: 0 },
  { name: "Models & Releases", slug: "models", description: "New AI model releases, benchmarks, comparisons, and open source drops", icon: "brain", color: "#8b5cf6", position: 1 },
  { name: "Make Money with AI", slug: "money", description: "Ways to earn income using AI tools, freelancing, building products, and side hustles", icon: "dollar-sign", color: "#10b981", position: 2 },
  { name: "Tutorials & Guides", slug: "tutorials", description: "How-to guides, courses, learning resources, and AI tool walkthroughs", icon: "book-open", color: "#f59e0b", position: 3 }
]

categories.each do |cat_attrs|
  Category.find_or_create_by!(slug: cat_attrs[:slug]) do |c|
    c.assign_attributes(cat_attrs)
  end
end

puts "Created #{Category.count} categories"

# Sources
sources_data = [
  # AI Tech
  { name: "OpenAI Blog", url: "https://openai.com/blog/rss.xml", source_type: "rss", category_slug: "ai-tech" },
  { name: "Anthropic News", url: "https://www.anthropic.com/rss.xml", source_type: "rss", category_slug: "ai-tech" },
  { name: "Google AI Blog", url: "https://blog.google/technology/ai/rss/", source_type: "rss", category_slug: "ai-tech" },
  { name: "DeepMind Blog", url: "https://deepmind.google/blog/rss.xml", source_type: "rss", category_slug: "ai-tech" },
  { name: "Meta AI Blog", url: "https://ai.meta.com/blog/rss/", source_type: "rss", category_slug: "ai-tech" },
  { name: "MIT Tech Review AI", url: "https://www.technologyreview.com/topic/artificial-intelligence/feed", source_type: "rss", category_slug: "ai-tech" },
  { name: "VentureBeat AI", url: "https://venturebeat.com/category/ai/feed/", source_type: "rss", category_slug: "ai-tech" },
  { name: "Ars Technica AI", url: "https://feeds.arstechnica.com/arstechnica/technology-lab", source_type: "rss", category_slug: "ai-tech" },

  # Models & Releases
  { name: "Hugging Face Blog", url: "https://huggingface.co/blog/feed.xml", source_type: "rss", category_slug: "models" },
  { name: "Hacker News", url: "https://hnrss.org/newest?q=AI+OR+LLM+OR+GPT+OR+Claude+OR+LLaMA+OR+machine+learning&count=20", source_type: "rss", category_slug: "models" },
  { name: "r/LocalLLaMA", url: "https://www.reddit.com/r/LocalLLaMA/.rss", source_type: "rss", category_slug: "models" },
  { name: "r/MachineLearning", url: "https://www.reddit.com/r/MachineLearning/.rss", source_type: "rss", category_slug: "models" },
  { name: "The Verge AI", url: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml", source_type: "rss", category_slug: "models" },

  # Make Money with AI
  { name: "IndieHackers AI", url: "https://www.indiehackers.com/feed?topic=ai", source_type: "rss", category_slug: "money" },
  { name: "r/artificial", url: "https://www.reddit.com/r/artificial/.rss", source_type: "rss", category_slug: "money" },
  { name: "AI Tool Report", url: "https://aitoolreport.com/feed", source_type: "rss", category_slug: "money" },
  { name: "Futurepedia", url: "https://www.futurepedia.io/feed", source_type: "rss", category_slug: "money" },

  # Tutorials & Guides
  { name: "Towards Data Science", url: "https://towardsdatascience.com/feed", source_type: "rss", category_slug: "tutorials" },
  { name: "freeCodeCamp AI", url: "https://www.freecodecamp.org/news/tag/artificial-intelligence/feed/", source_type: "rss", category_slug: "tutorials" },
  { name: "Real Python AI", url: "https://realpython.com/atom.xml", source_type: "rss", category_slug: "tutorials" },
  { name: "Analytics Vidhya", url: "https://www.analyticsvidhya.com/feed/", source_type: "rss", category_slug: "tutorials" }
]

sources_data.each do |source_data|
  category = Category.find_by!(slug: source_data[:category_slug])
  Source.find_or_create_by!(name: source_data[:name]) do |s|
    s.url = source_data[:url]
    s.source_type = source_data[:source_type]
    s.category = category
    s.active = true
  end
end

puts "Created #{Source.count} sources"
puts "Seeding complete!"
