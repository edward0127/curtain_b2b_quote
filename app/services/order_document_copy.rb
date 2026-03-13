class OrderDocumentCopy
  HEADING = "Curtain Order / Invoice".freeze
  SUBTITLE = "INVOICE / ORDER".freeze
  INTRO = "Thank you for your order. Please review the invoice details below.".freeze
  TERMS = "Order valid for 14 days unless otherwise stated.".freeze
  FOOTER = "Please contact us for any requested changes or delivery updates.".freeze

  def self.heading
    HEADING
  end

  def self.subtitle
    SUBTITLE
  end

  def self.intro
    INTRO
  end

  def self.terms
    TERMS
  end

  def self.footer
    FOOTER
  end
end
