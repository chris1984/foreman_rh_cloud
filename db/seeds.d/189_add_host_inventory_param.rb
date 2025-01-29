CommonParameter.without_auditing do
  params = [
    { name: "host_registration_insights_inventory", key_type: "boolean", value: true },
  ]

  params.each { |param| CommonParameter.find_or_create_by(param) }
end
