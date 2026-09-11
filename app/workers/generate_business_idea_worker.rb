class GenerateBusinessIdeaWorker
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 2

  def perform
    today = Date.current
    return if BusinessIdea.exists?(idea_date: today)

    Rails.logger.info "[BizIdea] Generating business idea for #{today}"

    recent_articles = Article.where("published_at > ?", 7.days.ago)
                             .includes(:category, :source)
                             .order(published_at: :desc)
                             .limit(50)

    return if recent_articles.empty?

    idea = generate_idea_from_articles(recent_articles)

    BusinessIdea.create!(
      title: idea[:title],
      description: idea[:description],
      how_to_start: idea[:how_to_start],
      tools_needed: idea[:tools_needed],
      expected_income: idea[:expected_income],
      difficulty: idea[:difficulty],
      category: idea[:category],
      source_article_ids: recent_articles.pluck(:id).first(10).join(","),
      featured: true,
      idea_date: today
    )

    Rails.logger.info "[BizIdea] Created: #{idea[:title]}"
  end

  private

  def generate_idea_from_articles(articles)
    categories = articles.map { |a| a.category&.name }.compact.uniq
    titles = articles.map(&:title).compact.first(20)
    summaries = articles.map(&:summary).compact.first(10)

    # Analyze trends from recent AI news
    trends = analyze_trends(articles)

    # Generate a practical business idea based on current AI landscape
    idea_templates = build_idea_pool(trends, titles, summaries)
    idea = idea_templates.sample

    {
      title: idea[:title],
      description: idea[:description],
      how_to_start: idea[:how_to_start],
      tools_needed: idea[:tools_needed],
      expected_income: idea[:expected_income],
      difficulty: idea[:difficulty],
      category: idea[:category]
    }
  end

  def analyze_trends(articles)
    trend_keywords = {
      "llm" => "Large Language Models",
      "agent" => "AI Agents",
      "automation" => "AI Automation",
      "image" => "AI Image Generation",
      "voice" => "Voice AI",
      "code" => "AI Code Generation",
      "video" => "AI Video",
      "data" => "AI Data Analytics",
      "chat" => "AI Chatbots",
      "api" => "AI APIs",
      "local" => "Local AI",
      "open source" => "Open Source AI",
      "startup" => "AI Startups",
      "money" => "AI Monetization",
      "freelance" => "AI Freelancing",
      "content" => "AI Content Creation",
      "marketing" => "AI Marketing",
      "ecommerce" => "AI E-commerce",
      "health" => "AI Healthcare",
      "education" => "AI Education"
    }

    found_trends = {}
    all_text = articles.map { |a| "#{a.title} #{a.summary}" }.join(" ").downcase

    trend_keywords.each do |keyword, label|
      count = all_text.scan(keyword).size
      found_trends[label] = count if count > 0
    end

    found_trends.sort_by { |_, v| -v }.first(5).to_h
  end

  def build_idea_pool(trends, titles, summaries)
    [
      {
        title: "AI-Powered Content Repurposing Service",
        description: "Build a service that takes long-form content (blog posts, podcasts, videos) and automatically repurposes them into social media posts, newsletters, short videos, and infographics using AI. Businesses are drowning in content creation needs.",
        how_to_start: "1. Sign up for OpenAI/Anthropic API access ($5-20/month to start)\n2. Build a simple web form where clients paste their content\n3. Use AI to generate platform-specific content variations\n4. Deliver via email or dashboard\n5. Charge $50-200 per content package",
        tools_needed: "OpenAI API or Claude API, simple web app (even a no-code tool like Carrd + Zapier), Stripe for payments",
        expected_income: "$500-3,000/month within 3 months. 10 clients at $100/package = $1,000/month.",
        difficulty: "Beginner",
        category: "Content Creation"
      },
      {
        title: "Local AI Setup Consultant",
        description: "With tools like Ollama and LM Studio making local AI accessible, help small businesses and individuals set up private AI on their own hardware. No data leaves their network — huge selling point for privacy-conscious clients.",
        how_to_start: "1. Master local AI deployment (Ollama, LM Studio, Stable Diffusion)\n2. Create a simple guide/portfolio site\n3. Offer 1-hour setup sessions via video call\n4. Charge $100-300 per session\n5. Offer monthly maintenance plans at $50/month",
        tools_needed: "A decent GPU-equipped PC for demos, Ollama, LM Studio, screen sharing software",
        expected_income: "$1,000-4,000/month. 5-10 consultations per month at $150 average.",
        difficulty: "Intermediate",
        category: "Consulting"
      },
      {
        title: "AI Stock Photo Generator",
        description: "Create and sell AI-generated stock photos and illustrations. Many businesses need specific images that don't exist in traditional stock libraries. Niche-specific AI images sell well on marketplaces.",
        how_to_start: "1. Set up Stable Diffusion or use Midjourney\n2. Identify underserved niches (specific industries, diverse representation)\n3. Generate high-quality images in batches\n4. Upload to stock photo sites (Adobe Stock, Shutterstock)\n5. Also sell directly via Gumroad or your own site",
        tools_needed: "Stable Diffusion (free) or Midjourney ($10/month), Photoshop/GIMP for touch-ups",
        expected_income: "$200-1,500/month passive income. Top sellers earn $5,000+/month.",
        difficulty: "Beginner",
        category: "Creative"
      },
      {
        title: "AI Email Marketing Writer",
        description: "Offer AI-powered email sequence writing for e-commerce businesses. Create welcome sequences, abandoned cart emails, product launches, and re-engagement campaigns. AI can draft 80% of the work, you refine the 20% that needs human touch.",
        how_to_start: "1. Learn email marketing fundamentals (free courses abound)\n2. Use AI to draft email sequences\n3. Build 3 sample sequences for different industries\n4. Reach out to e-commerce store owners on LinkedIn\n5. Charge $200-500 per email sequence",
        tools_needed: "Claude or GPT-4 API, email marketing knowledge, portfolio of sample sequences",
        expected_income: "$2,000-6,000/month. 5-10 clients per month at $300 average.",
        difficulty: "Beginner",
        category: "Marketing"
      },
      {
        title: "AI Data Entry & Document Processing Service",
        description: "Use AI to automate data entry, invoice processing, and document digitization for small businesses. What used to take hours of manual work can now be done in minutes with OCR + LLMs.",
        how_to_start: "1. Set up document processing pipeline (OCR + AI extraction)\n2. Target local small businesses (accountants, law firms, medical offices)\n3. Offer free trial processing of 10 documents\n4. Charge per document or monthly retainer\n5. Automate as much as possible for maximum profit margin",
        tools_needed: "Document AI API or open-source OCR, Claude/GPT for extraction, simple web interface",
        expected_income: "$1,500-5,000/month. 10 clients at $200/month retainer.",
        difficulty: "Intermediate",
        category: "Automation"
      },
      {
        title: "AI-Powered Resume & Cover Letter Service",
        description: "Help job seekers create ATS-optimized resumes and personalized cover letters using AI. The job market is competitive and people will pay for an edge. You provide the human expertise + AI efficiency.",
        how_to_start: "1. Study ATS optimization and resume best practices\n2. Create templates for different industries\n3. Use AI to customize for each job posting\n4. List on Fiverr, Upwork, or create a simple site\n5. Charge $50-150 per resume package",
        tools_needed: "AI API, resume templates, understanding of ATS systems, PDF generation tool",
        expected_income: "$1,000-4,000/month. 20 orders at $100 average.",
        difficulty: "Beginner",
        category: "Career Services"
      },
      {
        title: "AI Voice Agent for Small Businesses",
        description: "Build and sell AI phone answering agents for small businesses. Restaurants, dentists, plumbers — they all miss calls. An AI that can answer, book appointments, and answer FAQs costs pennies per call vs. a receptionist.",
        how_to_start: "1. Learn Vapi, Bland.ai, or Retell AI platforms\n2. Build a demo agent for a common use case\n3. Cold-call local businesses with missed call problems\n4. Charge setup fee ($200-500) + monthly ($50-150)\n5. Offer white-label to agencies",
        tools_needed: "Vapi/Bland.ai account ($0.10/min), phone number ($1/mo), simple script building",
        expected_income: "$2,000-8,000/month. 20 businesses at $100/month = $2,000 recurring.",
        difficulty: "Intermediate",
        category: "Automation"
      },
      {
        title: "AI Course Creator",
        description: "Use AI to rapidly create and sell online courses on platforms like Udemy, Skillshare, or your own Teachable site. AI can help write scripts, create slides, generate quizzes, and even produce voiceovers.",
        how_to_start: "1. Pick a topic you know + AI tools to enhance it\n2. Use AI to outline and script your course\n3. Create slides with AI-generated visuals\n4. Record with AI voiceover or your own voice\n5. Publish on Udemy/Teachable and market on social media",
        tools_needed: "AI API for content, screen recording software, slide design tool, course platform",
        expected_income: "$500-5,000/month passive. Top courses earn $10,000+/month.",
        difficulty: "Intermediate",
        category: "Education"
      },
      {
        title: "AI Social Media Management Agency",
        description: "Offer social media management powered by AI. Use AI to generate posts, captions, hashtags, and even schedule content. You manage 5-10 clients while AI does 80% of the content creation work.",
        how_to_start: "1. Learn social media marketing basics\n2. Set up AI content generation pipeline\n3. Create sample content for 3 niches\n4. Find 3-5 clients locally or on LinkedIn\n5. Charge $300-1,000/month per client",
        tools_needed: "AI API, scheduling tool (Buffer/Later), Canva Pro, analytics dashboard",
        expected_income: "$1,500-10,000/month. 5 clients at $500/month = $2,500.",
        difficulty: "Beginner",
        category: "Marketing"
      },
      {
        title: "AI-Powered Research Assistant Service",
        description: "Offer a research-as-a-service business. Use AI to quickly compile market research, competitor analysis, industry reports, and literature reviews. Target startups, consultants, and academics who need fast, thorough research.",
        how_to_start: "1. Build research templates for common request types\n2. Use AI for initial research pass, then validate with real sources\n3. Create professional report templates\n4. List on Upwork or create a simple landing page\n5. Charge $100-500 per research report",
        tools_needed: "Claude/GPT-4, web search capabilities, PDF/report templates, Google Scholar access",
        expected_income: "$1,500-6,000/month. 10 reports at $300 average.",
        difficulty: "Intermediate",
        category: "Research"
      },
      {
        title: "AI Photo Editing Studio",
        description: "Offer AI-powered photo editing services: background removal, object removal, style transfer, headshot enhancement, and product photo optimization. Charge per image or subscription. Perfect for e-commerce sellers and real estate agents.",
        how_to_start: "1. Master AI photo tools (Remove.bg, Stable Diffusion inpainting, GFPGAN)\n2. Create before/after portfolio\n3. Target e-commerce sellers and real estate agents\n4. List on Fiverr/Upwork or build simple site\n5. Charge $5-25 per image or $100-300/month subscription",
        tools_needed: "Stable Diffusion (free), Remove.bg API, Photoshop or GIMP, image hosting",
        expected_income: "$1,000-4,000/month. 200 images/month at $10 average.",
        difficulty: "Beginner",
        category: "Creative"
      },
      {
        title: "AI Translation & Localization Freelancer",
        description: "Use AI translation models to offer fast, affordable translation and localization services. AI handles the first pass, you provide human quality assurance. Target businesses expanding internationally.",
        how_to_start: "1. Master AI translation tools (DeepL API, GPT-4)\n2. Identify language pairs you can QA (even basic)\n3. Create translation memory for consistency\n4. Find clients on ProZ, Upwork, or LinkedIn\n5. Charge $0.05-0.15 per word (undercutting traditional rates)",
        tools_needed: "DeepL API or GPT-4, translation memory tool, QA checklist, project management",
        expected_income: "$2,000-6,000/month. 50,000 words/month at $0.08/word.",
        difficulty: "Beginner",
        category: "Language Services"
      }
    ]
  end
end
