defmodule NdflDividents do
  use Hound.Helpers
  @login_url "https://lkfl2.nalog.ru/lkfl/situations/3NDFL"

  def login do
    Hound.start_session()
    navigate_to(@login_url)
  end

  def run(file_path) do
    parsed_file = parse_file(file_path)

    Enum.each(parsed_file, fn _ -> click_add_income_button() end)
    toggle_expand_incomes(500)
    Enum.each(parsed_file, &fill_income/1)

    checkboxes = find_all_elements(:class, "jq-checkbox")

    Enum.each(checkboxes, fn checkbox ->
      click(checkbox)
      Process.sleep(500)
    end)

    toggle_expand_incomes(100)
  end

  defp parse_file(file_path) do
    file_path
    |> File.stream!(read_ahead: 1_000)
    |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)
    |> Stream.map(&csv_row_to_map/1)
    |> Stream.with_index()
    |> Enum.to_list()
  end

  def click_add_income_button() do
    add_button =
      find_element(
        :class,
        "src-modules-Taps-components-NDFL3-private-forms-IncomesForm-IncomesOutsideRFComponent-IncomeSources-IncomeSources-module__addButton"
      )

    click(add_button)
  end

  def fill_income({data, index}) do
    fill_name(index, data.name)
    fill_country(index, data.country)
    fill_income_type(index)
    fill_income_deduction(index)
    fill_total_amount(index, data.total_amount)
    fill_income_date(index, data.date)
    fill_payment_date(index, data.date)
    fill_currency(index, data.currency)
    fill_tax_amount(index, data.tax_paid_already)
  end

  defp fill_tax_amount(index, tax) do
    tax_amount_element = find_element(:id, income_element(index, "paymentAmountCurrency"))
    input_into_field(tax_amount_element, tax)
  end

  defp fill_currency(index, currency) do
    currency_element = find_element(:id, income_element(index, "currencyCode"))
    click(currency_element)
    currency |> currency_to_filed() |> send_text()
    send_keys(:enter)
  end

  defp fill_income_date(index, date) do
    fill_date(index, "incomeDate", date)
  end

  defp fill_payment_date(index, date) do
    fill_date(index, "taxPaymentDate", date)
  end

  defp fill_date(index, key, date) do
    date_element = find_element(:id, income_element(index, key))
    date_element = find_within_element(date_element, :tag, "input")
    input_into_field(date_element, date)
    send_keys(:enter)
  end

  defp fill_total_amount(index, amount) do
    amount_element = find_element(:id, income_element(index, "incomeAmountCurrency"))
    input_into_field(amount_element, amount)
  end

  defp fill_income_deduction(index) do
    deduction_element = find_element(:id, income_element(index, "taxDeductionCode"))
    click(deduction_element)
    send_text("Не предоставлять вычет")
    send_keys(:enter)
  end

  defp fill_income_type(index) do
    type_element = find_element(:id, income_element(index, "incomeTypeCode"))
    click(type_element)
    send_text("1010")
    send_keys(:enter)
  end

  defp fill_country(index, country) do
    country_element = find_element(:id, income_element(index, "oksm"))
    click(country_element)
    country |> country_to_filed() |> send_text()
    send_keys(:enter)
  end

  defp fill_name(index, name) do
    name_element = find_element(:id, income_element(index, "incomeSourceName"))
    input_into_field(name_element, name)
  end

  defp currency_to_filed("USD") do
    "840"
  end

  defp country_to_filed("США") do
    "840"
  end

  defp country_to_filed("Ирландия") do
    "372"
  end

  defp country_to_filed("Кипр") do
    "196"
  end

  defp country_to_filed("Нидерланды") do
    "528"
  end

  defp country_to_filed("Гонконг") do
    "344"
  end

  defp csv_row_to_map([
         _,
         date,
         _,
         name,
         _,
         country,
         amount_of_stocks,
         money_per_stock,
         _,
         tax_paid_already,
         _,
         currency
       ]) do
    amount_of_stocks = String.to_integer(amount_of_stocks)

    money_per_stock =
      money_per_stock
      |> String.replace(",", ".")
      |> Decimal.new()

    total_amount = amount_of_stocks |> Decimal.mult(money_per_stock) |> Decimal.to_string()

    tax_paid_already = String.replace(tax_paid_already, ",", ".")

    %{
      date: date,
      name: name,
      country: country,
      currency: currency,
      tax_paid_already: tax_paid_already,
      total_amount: total_amount
    }
  end

  def toggle_expand_incomes(sleep) do
    find_all_elements(
      :class,
      "src-modules-Taps-components-NDFL3-private-forms-IncomesForm-IncomesOutsideRFComponent-IncomeSources-IncomeSources-module__spoilerTitle"
    )
    |> Enum.each(fn element ->
      click(element)
      Process.sleep(sleep)
    end)
  end

  defp income_element(index, name) do
    "Ndfl3Package.payload.sheetB.sources[#{index}].#{name}"
  end
end
