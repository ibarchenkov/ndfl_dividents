defmodule NdflDividents do
  use Hound.Helpers
  alias NimbleCSV.RFC4180, as: CSV

  @login_url "https://lkfl2.nalog.ru/lkfl/login"

  @country_to_code %{
    "США" => "840",
    "Ирландия" => "372",
    "Кипр" => "196",
    "Нидерланды" => "528",
    "Гонконг" => "344",
    "Швейцарская Конфедерация" => "756",
    "Китай" => "156"
  }

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
    stream = File.stream!(file_path, read_ahead: 1_000)

    headers =
      stream
      |> CSV.parse_stream(skip_headers: false)
      |> Enum.take(1)
      |> hd()
      |> Enum.map(fn header -> header |> String.downcase() |> String.trim_trailing("*") end)

    stream
    |> CSV.parse_stream(skip_headers: true)
    |> Stream.map(fn row -> headers |> Enum.zip(row) |> Map.new() end)
    |> Stream.map(&csv_row_to_map/1)
    |> Stream.with_index()
    |> Enum.to_list()
  end

  def click_add_income_button() do
    add_button =
      find_element(
        :class,
        # "src-modules-Taps-components-NDFL3-private-forms-IncomesForm-IncomesOutsideRFComponent-IncomeSources-IncomeSources-module__addButton"
        "IncomeSources_addButton__1jhpg"
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
    country_element = find_element(:id, income_element(index, "oksmIst"))
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

  defp country_to_filed(country) do
    case Map.get(@country_to_code, country) do
      nil ->
        raise "Добавьте страну `#{country}` в массив @country_to_code и отправьте, пожалуйста, PR"

      code ->
        code
    end
  end

  defp csv_row_to_map(%{
         "дата выплаты" => date,
         "наименование ценной бумаги" => name,
         "страна эмитента" => country,
         "валюта" => currency,
         "сумма налога, удержанного агентом" => tax_paid_already,
         "сумма до удержания налога" => total_amount
       }) do
    %{
      date: date,
      name: name,
      country: country,
      currency: currency,
      tax_paid_already: String.replace(tax_paid_already, ",", "."),
      total_amount: String.replace(total_amount, ",", ".")
    }
  end

  def toggle_expand_incomes(sleep) do
    find_all_elements(
      :class,
      # "src-modules-Taps-components-NDFL3-private-forms-IncomesForm-IncomesOutsideRFComponent-IncomeSources-IncomeSources-module__spoilerTitle"
      "IncomeSources_incomeSourceSpoiler__2AMpN"
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
