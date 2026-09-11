require "test_helper"

class BankTest < ActiveSupport::TestCase
  test "payos_supported? returns true for supported banks and false for unsupported banks" do
    mb = Bank.new(name: "Military Bank", code: "MB", bin: "970422", short_name: "MB")
    acb = Bank.new(name: "Asia Commercial Bank", code: "ACB", bin: "970416", short_name: "ACB")
    bidv = Bank.new(name: "BIDV", code: "BIDV", bin: "970418", short_name: "BIDV")
    ocb = Bank.new(name: "OCB", code: "OCB", bin: "970448", short_name: "OCB")
    klb = Bank.new(name: "KienlongBank", code: "KLB", bin: "970452", short_name: "KLB")

    vcb = Bank.new(name: "Vietcombank", code: "VCB", bin: "970436", short_name: "VCB")
    tcb = Bank.new(name: "Techcombank", code: "TCB", bin: "970407", short_name: "TCB")

    assert mb.payos_supported?
    assert acb.payos_supported?
    assert bidv.payos_supported?
    assert ocb.payos_supported?
    assert klb.payos_supported?

    assert_not vcb.payos_supported?
    assert_not tcb.payos_supported?
  end

  test "payos_supported scope returns only supported banks" do
    mb = Bank.find_or_create_by!(code: "MB") do |b|
      b.name = "Military Bank"
      b.bin = "970422"
      b.short_name = "MB"
    end
    vcb = Bank.find_or_create_by!(code: "VCB") do |b|
      b.name = "Vietcombank"
      b.bin = "970436"
      b.short_name = "VCB"
    end

    supported_banks = Bank.payos_supported
    assert_includes supported_banks, mb
    assert_not_includes supported_banks, vcb
  end
end
