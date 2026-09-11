require "httparty"

class GenerateBusinessIdeaWorker
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 2

  MAX_RECENT_ARTICLES = 100
  RECENT_USED_LIMIT = 14

  def perform
    today = Date.current
    return if BusinessIdea.exists?(idea_date: today)

    Rails.logger.info "[BizIdea] Generating business idea for #{today}"

    recent_articles = Article.where("published_at > ?", 7.days.ago)
                             .includes(:category, :source)
                             .order(published_at: :desc)
                             .limit(MAX_RECENT_ARTICLES)

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
      game_plan: idea[:game_plan],
      starter_prompt: idea[:starter_prompt],
      trends: idea[:trends],
      source_article_ids: idea[:source_article_ids],
      featured: true,
      idea_date: today
    )

    Rails.logger.info "[BizIdea] Created: #{idea[:title]}"
  end

  private

  def generate_idea_from_articles(articles)
    trends = analyze_trends(articles)
    used_titles = recently_used_titles
    trends_summary = trend_summary(trends)

    idea = generate_with_llm(articles, trends, used_titles) || generate_with_rules(articles, trends, used_titles, trends_summary)

    {
      title: idea[:title],
      description: idea[:description],
      how_to_start: idea[:how_to_start],
      tools_needed: idea[:tools_needed],
      expected_income: idea[:expected_income],
      difficulty: idea[:difficulty],
      category: idea[:category],
      game_plan: idea[:game_plan],
      starter_prompt: idea[:starter_prompt],
      trends: trends_summary,
      source_article_ids: idea[:source_article_ids]
    }
  end

  def generate_with_rules(articles, trends, used_titles, trends_summary)
    excluded = used_titles.to_set
    candidates = templates.reject { |t| excluded.include?(t[:title]) }
    candidates = templates if candidates.empty?

    all_text = corpus(articles)

    scored = candidates.map do |t|
      score = t[:keywords].sum { |kw| all_text.scan(kw).size }
      [score, t]
    end

    max_score = scored.map(&:first).max.to_i
    best = scored.select { |s, _| s == max_score }
    best = scored.select { |s, _| s >= 1 } if best.empty? && max_score.zero? && scored.any? { |s, _| s >= 1 }

    template = best.empty? ? scored.sample : best.sample
    template = template.last if template.is_a?(Array) && template.size == 2 && template.last.is_a?(Hash)

    idea = template.to_h
    description = idea[:description].to_s
    idea[:description] = description.dup
    idea[:description] += "\n\nWhy now: #{trends_summary} — the last 7 days of AI news are full of it." if trends_summary.present?

    sources = select_source_articles(articles, idea[:keywords])
    idea[:source_article_ids] = sources.pluck(:id).join(",")
    idea[:game_plan] = build_game_plan(idea)
    idea[:starter_prompt] = build_starter_prompt(idea, trends_summary, sources)
    idea[:keywords] = nil
    idea
  end

  def generate_with_llm(articles, trends, used_titles)
    return nil unless ENV["OPENAI_API_KEY"].present?

    titles = articles.map(&:title).compact.first(12)
    summaries = articles.map(&:summary).compact.first(6)
    source_pool = select_source_articles(articles, trends.keys.map { |l| l.downcase })

    prompt = <<~PROMPT
      You are a veteran business strategist and startup mentor. Using ONLY the recent AI news below, create ONE
      original, practical, low-cost business idea a solo founder can start in their spare time THIS month. It must
      be clearly grounded in what is happening in AI right now.

      Today's top trends (keyword counts over the last 7 days): #{trends.keys.first(6).join(", ")}

      Recent AI news:
      #{titles.zip(summaries).map { |t, s| "- #{t}#{s.present? ? ": #{s}" : ""}" }.join("\n")}

      Recently published idea titles to AVOID repeating: #{used_titles.first(10).join("; ")}

      Respond with STRICT JSON only (no markdown fences, no commentary) matching exactly:
      {
        "title": "concise, specific, sellable name",
        "description": "2-3 sentences, concrete and practical",
        "how_to_start": "1. ...\\n2. ...\\n3. ... (4-6 numbered steps)",
        "tools_needed": "comma separated tools/services",
        "expected_income": "a realistic range plus the simple math behind it",
        "difficulty": "Beginner | Intermediate | Advanced",
        "category": "short category label",
        "game_plan": "Week 1 - ...[validate sub-task]: details\\nWeek 2 - ...[build]: details\\nWeek 3 - ...[pilot]: details\\nWeek 4 - ...[launch and charge]: details",
        "starter_prompt": "a full, ready-to-paste master prompt that asks for market validation, MVP scope, a 30-day plan, pricing tiers, risks, and outreach copy",
        "source_hints": ["keywords", "that match", "the news that inspired this"]
      }
    PROMPT

    body = HTTParty.post(
      "https://api.openai.com/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}",
        "Content-Type" => "application/json"
      },
      body: {
        model: ENV["OPENAI_MODEL"].presence || "gpt-4o-mini",
        temperature: 0.9,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: "You produce structured JSON business plans. Output raw JSON only." },
          { role: "user", content: prompt }
        ]
      }.to_json,
      timeout: 45
    )

    unless body.success?
      Rails.logger.warn "[BizIdea] LLM request failed (#{body.code}): #{body.body.first(300)}"
      return nil
    end

    parsed = JSON.parse(body.parsed_response.dig("choices", 0, "message", "content"))
    parsed = parsed["idea"] if parsed["idea"].is_a?(Hash)

    result = {
      title: parsed["title"].to_s.strip,
      description: parsed["description"].to_s.strip,
      how_to_start: parsed["how_to_start"].to_s.strip,
      tools_needed: parsed["tools_needed"].to_s.strip,
      expected_income: parsed["expected_income"].to_s.strip,
      difficulty: (%w[Beginner Intermediate Advanced].include?(parsed["difficulty"]) ? parsed["difficulty"] : "Intermediate"),
      category: parsed["category"].to_s.strip,
      game_plan: parsed["game_plan"].to_s.strip,
      starter_prompt: parsed["starter_prompt"].to_s.strip
    }

    raise "LLM returned blank title/description" if result[:title].blank? || result[:description].blank?
    raise "LLM repeated a recent title" if used_titles.include?(result[:title])

    hints = Array(parsed["source_hints"]).compact.reject(&:blank?)
    sources = hints.any? ? select_source_articles(articles, hints.map(&:downcase)) : source_pool
    sources = source_pool if sources.empty?
    result[:source_article_ids] = sources.pluck(:id).join(",")
    result[:game_plan] = normalize_game_plan(result[:game_plan])

    Rails.logger.info "[BizIdea] Generated with LLM"
    result
  rescue JSON::ParserError, StandardError => e
    Rails.logger.warn "[BizIdea] LLM generation failed, falling back to rules: #{e.class}: #{e.message}"
    nil
  end

  def analyze_trends(articles)
    trend_keywords = {
      "llm" => "Large Language Models",
      "agent" => "AI Agents",
      "automation" => "AI Automation",
      "image" => "AI Image Generation",
      "voice" => "Voice AI",
      "call" => "Voice AI",
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
      "education" => "AI Education",
      "search" => "AI Search",
      "reason" => "AI Reasoning",
      "assistant" => "AI Assistants",
      "support" => "AI Customer Support",
      "writing" => "AI Writing",
      "translate" => "AI Translation",
      "photo" => "AI Image Editing",
      "studio" => "AI Content Studios",
      "robotics" => "AI Robotics"
    }

    found_trends = {}
    all_text = corpus(articles)

    trend_keywords.each do |keyword, label|
      count = all_text.scan(keyword).size
      found_trends[label] = (found_trends[label].to_i + count) if count > 0
    end

    found_trends.sort_by { |_, v| -v }.first(6).to_h
  end

  def select_source_articles(articles, keywords)
    return articles.first(10) if keywords.blank?

    scored = articles.map do |a|
      text = "#{a.title} #{a.summary}".downcase
      hits = keywords.sum { |kw| text.scan(kw).size }
      [hits, a]
    end

    matches = scored.select { |hits, _| hits > 0 }.sort_by { |hits, _| -hits }
    Set.new(matches.map(&:last)).to_a.presence || articles.first(10)
  end

  def build_game_plan(idea)
    base = idea[:game_plan].to_s.presence
    return base if base.present?

    [
      "Week 1 - Validate the offer: interview 10 people in the target niche, price-check competitors offering #{idea[:category].downcase} today, and write down the exact promise the service keeps.",
      "Week 2 - Build the MVP: assemble the tool stack (#{idea[:tools_needed]}), create a demo deliverable, and set up a simple landing page or listing.",
      "Week 3 - Run 2-3 pilots: deliver at a discount or free, collect feedback, and fix the single biggest source of friction.",
      "Week 4 - Launch and charge: publish the offer in 3 relevant communities, follow up with pilot leads, and close the first 3 paying customers."
    ].join("\n")
  end

  def normalize_game_plan(plan)
    return plan if plan.to_s.scan(/week\s*\d/i).size >= 4

    lines = plan.to_s.split("\n").map(&:strip).reject(&:blank?)
    weeks = %w[Validate the offer Build the MVP Run a paid pilot Launch and charge]
    built = lines.first(3).map.with_index do |line, i|
      "Week #{i + 1} - #{line}"
    end
    (built + [weeks[lines.length]]).compact_blank.join("\n") if weeks[lines.length]
  end

  def build_starter_prompt(idea, trends_summary, sources)
    trend_lines = trends_summary.to_s.split("\n").first(4).map { |t| "- #{t}" }.join("\n")
    source_lines = sources.first(3).map { |a| "- #{a.title}" }.join("\n")

    <<~PROMPT.strip
      Act as an expert startup mentor and go-to-market strategist with 15 years of experience launching small, AI-powered service businesses. I am about to start:

      "#{idea[:title]}"

      THE BUSINESS
      - Concept: #{idea[:description]}
      - Category: #{idea[:category]} | Difficulty: #{idea[:difficulty]}
      - Income target: #{idea[:expected_income]}
      - Tool stack: #{idea[:tools_needed]}

      THE MARKET RIGHT NOW
      #{trend_lines.presence || "- (no specific trend data)"}

      RECENT NEWS SUPPORTING THIS IDEA
      #{source_lines.presence || "- (none yet)"}

      DELIVER
      1. Market validation checklist - the assumptions to test this week on a minimal budget, and how to test each one
      2. MVP scope - the smallest sellable version of this business and the exact tools to build it
      3. A 30-day execution plan that ends with a first paying customer
      4. Three pricing tiers with names and price points
      5. The 5 biggest risks and how to mitigate each
      6. A copy-paste outreach message to land the first 5 customers

      Be concrete, practical, and skeptical. No generic advice.
    PROMPT
  end

  def corpus(articles)
    @corpus ||= articles.map { |a| "#{a.title} #{a.summary}" }.join(" ").downcase
  end

  def trend_summary(trends)
    trends.first(5).map { |label, count| "#{label} (in #{count} stories)" }.join("\n")
  end

  def recently_used_titles
    BusinessIdea.recent.limit(RECENT_USED_LIMIT).pluck(:title)
  end

  def templates
    @templates ||= [
      {
        title: "AI-Powered Content Repurposing Service",
        description: "Build a service that takes long-form content (blog posts, podcasts, videos) and automatically repurposes them into social media posts, newsletters, short videos, and infographics using AI. Businesses are drowning in content creation needs.",
        how_to_start: "1. Sign up for OpenAI/Anthropic API access ($5-20/month to start)\n2. Build a simple web form where clients paste their content\n3. Use AI to generate platform-specific content variations\n4. Deliver via email or dashboard\n5. Charge $50-200 per content package",
        tools_needed: "OpenAI API or Claude API, simple web app (even a no-code tool like Carrd + Zapier), Stripe for payments",
        expected_income: "$500-3,000/month within 3 months. 10 clients at $100/package = $1,000/month.",
        difficulty: "Beginner",
        category: "Content Creation",
        keywords: %w[content repurpos social newsletter video podcast post blog],
        game_plan: [
          "Week 1 - Validate the offer: interview 8-10 creators and small businesses posting regularly, and confirm which output format (newsletter, shorts, LinkedIn posts) they want most.",
          "Week 2 - Build the MVP: wire up OpenAI/Claude to a simple paste-a-link form, ship 3 demo repurposing packages, and mock up the deliverable format in Canva.",
          "Week 3 - Run 2-3 pilots: repurpose 10 pieces of content for 2-3 creators for free, and refine the output until clients say it feels finished.",
          "Week 4 - Launch and charge: turn pilots into paid $100-200 packages, publish the offer in creator communities, and ask pilots for referrals."
        ].join("\n")
      },
      {
        title: "Local AI Setup Consultant",
        description: "With tools like Ollama and LM Studio making local AI accessible, help small businesses and individuals set up private AI on their own hardware. No data leaves their network — huge selling point for privacy-conscious clients.",
        how_to_start: "1. Master local AI deployment (Ollama, LM Studio, Stable Diffusion)\n2. Create a simple guide/portfolio site\n3. Offer 1-hour setup sessions via video call\n4. Charge $100-300 per session\n5. Offer monthly maintenance plans at $50/month",
        tools_needed: "A decent GPU-equipped PC for demos, Ollama, LM Studio, screen sharing software",
        expected_income: "$1,000-4,000/month. 5-10 consultations per month at $150 average.",
        difficulty: "Intermediate",
        category: "Consulting",
        keywords: %w[local ollama open source self hosting open-source private gpu llama],
        game_plan: [
          "Week 1 - Validate the offer: identify 5 local businesses that genuinely can't share data with cloud AI, and confirm the pain (privacy, cost, compliance) is real enough to pay for.",
          "Week 2 - Build the MVP: create a repeatable 1-hour setup script, a demo on your own hardware, and a one-page service sheet with three packages.",
          "Week 3 - Run 2 pilot sessions: set up Ollama/LM Studio for two clients at a discount, fix the rough edges, and document a before/after win.",
          "Week 4 - Launch and charge: list the service up locally and on LinkedIn, offer the maintenance retainer, and close 3 setup sessions."
        ].join("\n")
      },
      {
        title: "AI Stock Photo Generator",
        description: "Create and sell AI-generated stock photos and illustrations. Many businesses need specific images that don't exist in traditional stock libraries. Niche-specific AI images sell well on marketplaces.",
        how_to_start: "1. Set up Stable Diffusion or use Midjourney\n2. Identify underserved niches (specific industries, diverse representation)\n3. Generate high-quality images in batches\n4. Upload to stock photo sites (Adobe Stock, Shutterstock)\n5. Also sell directly via Gumroad or your own site",
        tools_needed: "Stable Diffusion (free) or Midjourney ($10/month), Photoshop/GIMP for touch-ups",
        expected_income: "$200-1,500/month passive income. Top sellers earn $5,000+/month.",
        difficulty: "Beginner",
        category: "Creative",
        keywords: %w[image photo stock generate diffusion midjourney visual picture design],
        game_plan: [
          "Week 1 - Niche pick: study which image searches are underserved (industry close-ups, diverse small-business shots), pick 2 niches, and audit what sells on Adobe Stock.",
          "Week 2 - Production line: build a repeatable prompt-to-collection pipeline, generate and cull 100-200 images, and touch up the keepers.",
          "Week 3 - Publish: upload 50+ images across 2-3 marketplaces and your own Gumroad, with strong keywords and categories.",
          "Week 4 - Optimize: check download data, double down on the winners, subscribe to a few buyer searches, and schedule weekly generation batches."
        ].join("\n")
      },
      {
        title: "AI Email Marketing Writer",
        description: "Offer AI-powered email sequence writing for e-commerce businesses. Create welcome sequences, abandoned cart emails, product launches, and re-engagement campaigns. AI can draft 80% of the work, you refine the 20% that needs human touch.",
        how_to_start: "1. Learn email marketing fundamentals (free courses abound)\n2. Use AI to draft email sequences\n3. Build 3 sample sequences for different industries\n4. Reach out to e-commerce store owners on LinkedIn\n5. Charge $200-500 per email sequence",
        tools_needed: "Claude or GPT-4 API, email marketing knowledge, portfolio of sample sequences",
        expected_income: "$2,000-6,000/month. 5-10 clients per month at $300 average.",
        difficulty: "Beginner",
        category: "Marketing",
        keywords: %w[email marketing campaign sequence subscriber customer ecommerce cart launch],
        game_plan: [
          "Week 1 - Validate the offer: talk to 5-8 e-commerce owners about their email numbers, and confirm cold lists/abandoned cart recovery is a real worry they have budget for.",
          "Week 2 - Build the MVP: write 3 polished sample sequences (welcome, abandoned cart, launch) using AI + human editing, and put them in a simple portfolio.",
          "Week 3 - Run pilots: draft one real sequence for 2 stores at a discount in exchange for a testimonial, and track one open/click metric.",
          "Week 4 - Launch and charge: post the portfolio on LinkedIn/X and relevant communities, price at $200-500 per sequence, and follow up with pilot stores."
        ].join("\n")
      },
      {
        title: "AI Data Entry & Document Processing Service",
        description: "Use AI to automate data entry, invoice processing, and document digitization for small businesses. What used to take hours of manual work can now be done in minutes with OCR + LLMs.",
        how_to_start: "1. Set up document processing pipeline (OCR + AI extraction)\n2. Target local small businesses (accountants, law firms, medical offices)\n3. Offer free trial processing of 10 documents\n4. Charge per document or monthly retainer\n5. Automate as much as possible for maximum profit margin",
        tools_needed: "Document AI API or open-source OCR, Claude/GPT for extraction, simple web interface",
        expected_income: "$1,500-5,000/month. 10 clients at $200/month retainer.",
        difficulty: "Intermediate",
        category: "Automation",
        keywords: %w[data entry document ocr invoice extraction digitization workflow process],
        game_plan: [
          "Week 1 - Validate the offer: pick one vertical (accounting, real estate, or medical), interview 5 firms about hours lost to data entry, and price the retainer.",
          "Week 2 - Build the MVP: assemble an OCR + LLM extraction pipeline that handles one document type end to end, with a clean output (CSV or their tool).",
          "Week 3 - Pilot: process 100 real documents across 2-3 firms for free with a verified accuracy promise, and fix the failure cases.",
          "Week 4 - Launch and charge: convert pilots to $200-400/month retainers, standardize onboarding, and target 3 more firms in the same vertical."
        ].join("\n")
      },
      {
        title: "AI-Powered Resume & Cover Letter Service",
        description: "Help job seekers create ATS-optimized resumes and personalized cover letters using AI. The job market is competitive and people will pay for an edge. You provide the human expertise + AI efficiency.",
        how_to_start: "1. Study ATS optimization and resume best practices\n2. Create templates for different industries\n3. Use AI to customize for each job posting\n4. List on Fiverr, Upwork, or create a simple site\n5. Charge $50-150 per resume package",
        tools_needed: "AI API, resume templates, understanding of ATS systems, PDF generation tool",
        expected_income: "$1,000-4,000/month. 20 orders at $100 average.",
        difficulty: "Beginner",
        category: "Career Services",
        keywords: %w[resume cover letter job career ats interview hire employment],
        game_plan: [
          "Week 1 - Validate the offer: study what ATS parsing tools score on, collect 3 real job listings, and interview 5 active job seekers about their resume blockers.",
          "Week 2 - Build the MVP: create industry resume templates, a 15-minute intake form, and an AI + human editing flow that produces a polished PDF.",
          "Week 3 - Pilot: do 5 resumes at $29-49 or free, gather before/after ATS scores, and collect testimonials.",
          "Week 4 - Launch and charge: list on Fiverr/Upwork at $50-150, add the cover letter add-on, and publish before/after examples on social."
        ].join("\n")
      },
      {
        title: "AI Voice Agent for Small Businesses",
        description: "Build and sell AI phone answering agents for small businesses. Restaurants, dentists, plumbers — they all miss calls. An AI that can answer, book appointments, and answer FAQs costs pennies per call vs. a receptionist.",
        how_to_start: "1. Learn Vapi, Bland.ai, or Retell AI platforms\n2. Build a demo agent for a common use case\n3. Cold-call local businesses with missed call problems\n4. Charge setup fee ($200-500) + monthly ($50-150)\n5. Offer white-label to agencies",
        tools_needed: "Vapi/Bland.ai account ($0.10/min), phone number ($1/mo), simple script building",
        expected_income: "$2,000-8,000/month. 20 businesses at $100/month = $2,000 recurring.",
        difficulty: "Intermediate",
        category: "Automation",
        keywords: %w[voice call phone agent answering appointment receptionist customer service],
        game_plan: [
          "Week 1 - Validate the offer: pick a niche (dentists, plumbers, or restaurants), call 10 of them as a customer to see missed-call reality, and price the monthly plan.",
          "Week 2 - Build the MVP: craft a demo agent on Vapi or Retell that books appointments and answers FAQs for one niche, and record 3 real call demos.",
          "Week 3 - Pilot: run 2 live pilots with real businesses at a discount, handle objections, and refine the script and handoff.",
          "Week 4 - Launch and charge: land 3 paying clients at $100-200/month with a $200-500 setup fee, and build a referral offer for the niche."
        ].join("\n")
      },
      {
        title: "AI Course Creator",
        description: "Use AI to rapidly create and sell online courses on platforms like Udemy, Skillshare, or your own Teachable site. AI can help write scripts, create slides, generate quizzes, and even produce voiceovers.",
        how_to_start: "1. Pick a topic you know + AI tools to enhance it\n2. Use AI to outline and script your course\n3. Create slides with AI-generated visuals\n4. Record with AI voiceover or your own voice\n5. Publish on Udemy/Teachable and market on social media",
        tools_needed: "AI API for content, screen recording software, slide design tool, course platform",
        expected_income: "$500-5,000/month passive. Top courses earn $10,000+/month.",
        difficulty: "Intermediate",
        category: "Education",
        keywords: %w[course learn tutorial teach udemy educate training skills student],
        game_plan: [
          "Week 1 - Validate the offer: pick a niche you can teach faster than the average person, and verify real demand by searching enrollments and community questions.",
          "Week 2 - Build the MVP: script and record one complete module (5-7 lessons) with AI-assisted slides and voiceover, and validate it with 5 early viewers.",
          "Week 3 - Finish the course: complete 4-5 modules, add quizzes and resources, and polish audio/visual consistency.",
          "Week 4 - Launch: publish on Udemy/Teachable at launch-week pricing, promote in 5 relevant communities, and collect reviews to lift ranking."
        ].join("\n")
      },
      {
        title: "AI Social Media Management Agency",
        description: "Offer social media management powered by AI. Use AI to generate posts, captions, hashtags, and even schedule content. You manage 5-10 clients while AI does 80% of the content creation work.",
        how_to_start: "1. Learn social media marketing basics\n2. Set up AI content generation pipeline\n3. Create sample content for 3 niches\n4. Find 3-5 clients locally or on LinkedIn\n5. Charge $300-1,000/month per client",
        tools_needed: "AI API, scheduling tool (Buffer/Later), Canva Pro, analytics dashboard",
        expected_income: "$1,500-10,000/month. 5 clients at $500/month = $2,500.",
        difficulty: "Beginner",
        category: "Marketing",
        keywords: %w[social media post caption brand instagram tiktok marketing audience],
        game_plan: [
          "Week 1 - Validate the offer: pick one niche you understand, interview 5-6 small businesses posting inconsistently, and confirm they'd pay $300-500/month for done-for-you content.",
          "Week 2 - Build the MVP: create a 2-week sample content calendar for your niche using an AI pipeline, and prepare 3 example portfolios.",
          "Week 3 - Pilot: run 2 pilot accounts at a discount, schedule 4 weeks of content, and show simple growth (follows, reach) in the analytics.",
          "Week 4 - Launch and charge: sign 2-3 paying clients, standardize the monthly package, and build a referral path."
        ].join("\n")
      },
      {
        title: "AI-Powered Research Assistant Service",
        description: "Offer a research-as-a-service business. Use AI to quickly compile market research, competitor analysis, industry reports, and literature reviews. Target startups, consultants, and academics who need fast, thorough research.",
        how_to_start: "1. Build research templates for common request types\n2. Use AI for initial research pass, then validate with real sources\n3. Create professional report templates\n4. List on Upwork or create a simple landing page\n5. Charge $100-500 per research report",
        tools_needed: "Claude/GPT-4, web search capabilities, PDF/report templates, Google Scholar access",
        expected_income: "$1,500-6,000/month. 10 reports at $300 average.",
        difficulty: "Intermediate",
        category: "Research",
        keywords: %w[research report analysis market competitor document study paper insight],
        game_plan: [
          "Week 1 - Validate the offer: interview 5 freelancers/consultants/startups about how much time research reports eat, and confirm their report budget.",
          "Week 2 - Build the MVP: create 3 report templates (market scan, competitor teardown, literature review) and a research pipeline with cited sources.",
          "Week 3 - Pilot: deliver 2-3 reports at $50-100 to get real feedback on depth, citations, and format.",
          "Week 4 - Launch and charge: list on Upwork and LinkedIn at $150-500/report, add a monthly retainer option, and ask pilots for testimonials."
        ].join("\n")
      },
      {
        title: "AI Photo Editing Studio",
        description: "Offer AI-powered photo editing services: background removal, object removal, style transfer, headshot enhancement, and product photo optimization. Charge per image or subscription. Perfect for e-commerce sellers and real estate agents.",
        how_to_start: "1. Master AI photo tools (Remove.bg, Stable Diffusion inpainting, GFPGAN)\n2. Create before/after portfolio\n3. Target e-commerce sellers and real estate agents\n4. List on Fiverr/Upwork or build simple site\n5. Charge $5-25 per image or $100-300/month subscription",
        tools_needed: "Stable Diffusion (free), Remove.bg API, Photoshop or GIMP, image hosting",
        expected_income: "$1,000-4,000/month. 200 images/month at $10 average.",
        difficulty: "Beginner",
        category: "Creative",
        keywords: %w[photo edit background retouch headshot product image ecommerce real estate],
        game_plan: [
          "Week 1 - Validate the offer: study what buyers search on Fiverr in photo editing, and interview 5 e-commerce or real-estate sellers about volume and pain points.",
          "Week 2 - Build the MVP: lock a fast edit workflow (SD inpainting + Remove.bg + touch-ups), create a 15-item before/after portfolio, and define per-image pricing.",
          "Week 3 - Pilot: edit 50-100 real images at reduced volume price, measure turnaround, and tighten the quality bar.",
          "Week 4 - Launch and charge: list on Fiverr/Upwork, pitch subscription packages to 5 e-commerce sellers, and convert pilots to retainer clients."
        ].join("\n")
      },
      {
        title: "AI Translation & Localization Freelancer",
        description: "Use AI translation models to offer fast, affordable translation and localization services. AI handles the first pass, you provide human quality assurance. Target businesses expanding internationally.",
        how_to_start: "1. Master AI translation tools (DeepL API, GPT-4)\n2. Identify language pairs you can QA (even basic)\n3. Create translation memory for consistency\n4. Find clients on ProZ, Upwork, or LinkedIn\n5. Charge $0.05-0.15 per word (undercutting traditional rates)",
        tools_needed: "DeepL API or GPT-4, translation memory tool, QA checklist, project management",
        expected_income: "$2,000-6,000/month. 50,000 words/month at $0.08/word.",
        difficulty: "Beginner",
        category: "Language Services",
        keywords: %w[translation translate language localization multilingual global market],
        game_plan: [
          "Week 1 - Validate the offer: pick 1-2 language pairs you can QA well, and confirm who needs content translated (e-commerce, SaaS, agencies) in those pairs.",
          "Week 2 - Build the MVP: set up DeepL/GPT-4 workflow with a QA checklist, a translation memory, and a sample localized page to show quality.",
          "Week 3 - Pilot: translate 5,000-10,000 words for 2 clients at a discount, get feedback on tone and terminology, and document the process.",
          "Week 4 - Launch and charge: list on Upwork/ProZ at $0.05-0.15/word, add a subscription for ongoing localization, and convert pilots to recurring work."
        ].join("\n")
      }
    ]
  end
end