# frozen_string_literal: true

# A comprehensive tax intake flow with 17 steps and multiple branching paths.
# This exercises all rule types: contains, equals, greater_than, less_than, not_empty, all, any.
#
# Flow graph summary:
#
#   filing_status -> dependents -> income_types
#     -> [if Business]    business_count -> [if >2] complex_business_info -> business_details
#                                        -> [else]  business_details
#     -> [if Investment]  investment_details -> [if Crypto] crypto_details
#     -> [if Rental]      rental_details
#     -> state_filing -> foreign_accounts -> [if yes] foreign_account_details
#                                         -> deduction_types
#     -> [if Charitable]  charitable_amount -> [if >5000] charitable_documentation
#     -> contact_info -> review (end)

COMPLEX_TAX_INTAKE = FlowEngine.define do
  start :filing_status

  # --- Step 1: Filing Status ---
  step :filing_status do
    type :single_select
    question "What is your filing status for 2025?"
    options %w[single married_filing_jointly married_filing_separately head_of_household]
    transition to: :dependents
  end

  # --- Step 2: Dependents ---
  step :dependents do
    type :number
    question "How many dependents do you have?"
    transition to: :income_types
  end

  # --- Step 3: Income Types (multi-select, main branching point) ---
  step :income_types do
    type :multi_select
    question "Select all income types that apply to you in 2025."
    options %w[W2 1099 Business Investment Rental Retirement]
    transition to: :business_count, if_rule: contains(:income_types, "Business")
    transition to: :investment_details, if_rule: contains(:income_types, "Investment")
    transition to: :rental_details, if_rule: contains(:income_types, "Rental")
    transition to: :state_filing
  end

  # --- Step 4: Business Count ---
  step :business_count do
    type :number
    question "How many total businesses do you own or are a partner in?"
    transition to: :complex_business_info,
               if_rule: greater_than(:business_count, 2)
    transition to: :business_details
  end

  # --- Step 5: Complex Business Info (only if >2 businesses) ---
  step :complex_business_info do
    type :text
    question "With more than 2 businesses, please provide your primary EIN and a brief description of each entity."
    transition to: :business_details
  end

  # --- Step 6: Business Details ---
  step :business_details do
    type :number_matrix
    question "How many of each business type do you own?"
    fields %w[RealEstate SCorp CCorp Trust LLC]
    transition to: :investment_details, if_rule: contains(:income_types, "Investment")
    transition to: :rental_details, if_rule: contains(:income_types, "Rental")
    transition to: :state_filing
  end

  # --- Step 7: Investment Details ---
  step :investment_details do
    type :multi_select
    question "What types of investments do you hold?"
    options %w[Stocks Bonds Crypto RealEstate MutualFunds]
    transition to: :crypto_details, if_rule: contains(:investment_details, "Crypto")
    transition to: :rental_details, if_rule: contains(:income_types, "Rental")
    transition to: :state_filing
  end

  # --- Step 8: Crypto Details (only if crypto investments) ---
  step :crypto_details do
    type :text
    question "Please describe your cryptocurrency transactions (exchanges used, approximate number of transactions)."
    transition to: :rental_details, if_rule: contains(:income_types, "Rental")
    transition to: :state_filing
  end

  # --- Step 9: Rental Details ---
  step :rental_details do
    type :number_matrix
    question "Provide details about your rental properties."
    fields %w[Residential Commercial Vacation]
    transition to: :state_filing
  end

  # --- Step 10: State Filing ---
  step :state_filing do
    type :multi_select
    question "Which states do you need to file in?"
    options %w[California NewYork Texas Florida Illinois Other]
    transition to: :foreign_accounts
  end

  # --- Step 11: Foreign Accounts ---
  step :foreign_accounts do
    type :single_select
    question "Do you have any foreign financial accounts (bank accounts, securities, or financial assets)?"
    options %w[yes no]
    transition to: :foreign_account_details, if_rule: equals(:foreign_accounts, "yes")
    transition to: :deduction_types
  end

  # --- Step 12: Foreign Account Details ---
  step :foreign_account_details do
    type :number
    question "How many foreign accounts do you have?"
    transition to: :deduction_types
  end

  # --- Step 13: Deduction Types (multi-select) ---
  step :deduction_types do
    type :multi_select
    question "Which additional deductions apply to you?"
    options %w[Medical Charitable Education Mortgage None]
    transition to: :charitable_amount, if_rule: contains(:deduction_types, "Charitable")
    transition to: :contact_info
  end

  # --- Step 14: Charitable Amount ---
  step :charitable_amount do
    type :number
    question "What is your total estimated charitable contribution amount for 2025?"
    transition to: :charitable_documentation,
               if_rule: greater_than(:charitable_amount, 5000)
    transition to: :contact_info
  end

  # --- Step 15: Charitable Documentation (only if >$5000) ---
  step :charitable_documentation do
    type :text
    question "For charitable contributions over $5,000, please list the organizations and amounts."
    transition to: :contact_info
  end

  # --- Step 16: Contact Info ---
  step :contact_info do
    type :text
    question "Please provide your contact information (name, email, phone)."
    transition to: :review
  end

  # --- Step 17: Review / Summary (terminal step) ---
  step :review do
    type :text
    question "Thank you! Please review your information. Type 'confirm' to submit."
  end
end
