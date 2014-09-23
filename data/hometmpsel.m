
__CMD_DROP_PROC(RadiusBillsDeals_IU_CreateBill)
create procedure RadiusBillsDeals_IU_CreateBill
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/* . Author: Evgeny Bugaev                                                                              */
/*                                                                                                      */
/*  ѕроцедура дл€ вставки детальных записей про вексел€ в операци€х.                                    */
/*  ¬ызываетс€ из пользовательского интерфейса.                                                         */
/*------------------------------------------------------------------------------------------------------*/
(
   @ActionId                    numeric(15),
   @DealType                    char(1),
   @DealLeg                     char(1),

   @Price                       float,
   @Accrued                     float,
   @Price2                      float,
   @Accrued2                    float,
   @YTM                         float,
   @BillSeries                  varchar(32),
   @BillNumberStr               varchar(32),
   @BillNumber                  numeric(18),
   @BillNumberTo                numeric(18),
   @Cpty_Id_Issuer              integer,
   @IssuerType                  char(1),
   @BillType                    char(1),
   @FaceValue                   float,
   @Currencies_Id               integer,
   @IssueDate                   datetime,
   @InterestRate                float,
   @InterestAmount              float = null,
   @EarlyInterestRate           float = null,

   @Basis                       char(1),
   @Cpty_Id_Holder              integer,
   @Comments                    varchar(255),
   @Cpty_Id_Guarantor           integer,
   @IssuePlace                  varchar(255),
   @MaturityDateType            char(1),
   @MaturityTermNumber          integer,
   @MaturityTermPeriod          char(1),
   @MaturityDate                datetime,
   @MaturityDateLast            datetime,

   @PaymentPlace                varchar(255),
   @Currencies_Id_Payment       integer,
   @PaymentRateType             char(1),
   @PaymentRate                 float,
   @PaymentRateDateType         char(1),
   @PaymentRateDate             datetime

)
as

declare
   @RadiusBills_Id numeric(15),
   @BatchOfBills   char(1),
   @errmsg         varchar(100)

begin

   select @BatchOfBills = case when @BillNumberTo is null then 'N' else 'Y' end

   select @DealLeg = case when @DealLeg in ('B','S') then @DealLeg else '*' end

   -- если это не пачка векселей и вексель не должен создатьс€ в результате этой операции, то надо проверить, нет ли уже такого вексел€.
   if @BatchOfBills = 'N' and not
            (@DealType in (__Bill_DealType_Own_Issue, __Bill_DealType_Branch_Issue) or
             @DealType in (__Bill_DealType_Own_Exchange, __Bill_DealType_Branch_Exchange) and @DealLeg = 'S')
      select @RadiusBills_Id = min(RadiusBills_Id) from RadiusBills
      where Cpty_Id_Issuer = @Cpty_Id_Issuer
      and BillSeries = @BillSeries
      and BillNumber = @BillNumber
      and BatchOfBills = 'N'


   -- проверки корректности должны быть здесь:

   if @MaturityDateType = 'F' and @MaturityDate is null
      select @errmsg = 'Ќе указана дата погашени€ вексел€  серии "' + @BillSeries + '" с номером ' + convert(varchar, @BillNumber)




   if @RadiusBills_Id is null
   begin
      insert RadiusBills(
         ActionId, ActionDatetime, BatchOfBills, BillSeries, BillNumberStr, BillNumber, BillNumberTo,
         Cpty_Id_Issuer, IssuerType, BillType, FaceValue, Currencies_Id, IssueDate, InterestRate, InterestAmount, EarlyInterestRate, Basis,
         Cpty_Id_Holder, Comments, Cpty_Id_Guarantor, IssuePlace, MaturityDateType, MaturityTermNumber,
         MaturityTermPeriod, MaturityDate, MaturityDateLast, PaymentPlace, Currencies_Id_Payment, PaymentRateType,
         PaymentRate, PaymentRateDateType, PaymentRateDate)
      values (
         @ActionId, getdate(), @BatchOfBills, @BillSeries, @BillNumberStr, @BillNumber, @BillNumberTo,
         @Cpty_Id_Issuer, @IssuerType, @BillType, @FaceValue, @Currencies_Id, @IssueDate, @InterestRate, @InterestAmount, @EarlyInterestRate, @Basis,
         @Cpty_Id_Holder, @Comments, @Cpty_Id_Guarantor, @IssuePlace, @MaturityDateType, @MaturityTermNumber,
         @MaturityTermPeriod, @MaturityDate, @MaturityDateLast, @PaymentPlace, @Currencies_Id_Payment, @PaymentRateType,
         @PaymentRate, @PaymentRateDateType, @PaymentRateDate)

      select @RadiusBills_Id = @@identity
   end
   else if @DealType in ( __Bill_DealType_Own_Issue,
                          __Bill_DealType_Branch_Issue,
                          __Bill_DealType_ThirdParty_Buy,
                          __Bill_DealType_ThirdParty_RevRepo)
            or (@DealType = __Bill_DealType_Own_Exchange and @DealLeg = 'S') -- выпуск собственных векселей в результате мены
            or (@DealType = __Bill_DealType_Branch_Exchange and @DealLeg = 'S') -- выпуск векселей филииала в результате мены
            or (@DealType = __Bill_DealType_ThirdParty_Exchange and @DealLeg = 'B') -- получение чужих векселей в результате мены
   begin
      -- обновл€м описание вексел€ в том случае, когда вексель создаЄтс€ в результате этой операции
      update RadiusBills set
      	BillNumberStr = @BillNumberStr,
      	IssuerType = @IssuerType,
      	BillType = @BillType,
      	FaceValue = @FaceValue,
      	Currencies_Id = @Currencies_Id,
      	IssueDate = @IssueDate,
      	InterestRate = @InterestRate,
         InterestAmount = @InterestAmount,
         EarlyInterestRate = @EarlyInterestRate,
      	Basis = @Basis,
      	Cpty_Id_Holder = @Cpty_Id_Holder,
      	Comments = @Comments,
      	Cpty_Id_Guarantor = @Cpty_Id_Guarantor,
      	IssuePlace = @IssuePlace,
      	MaturityDateType = @MaturityDateType,
      	MaturityTermNumber = @MaturityTermNumber,
      	MaturityTermPeriod = @MaturityTermPeriod,
      	MaturityDate = @MaturityDate,
      	MaturityDateLast = @MaturityDateLast,
      	PaymentPlace = @PaymentPlace,
      	Currencies_Id_Payment = @Currencies_Id_Payment,
      	PaymentRateType = @PaymentRateType,
      	PaymentRate = @PaymentRate,
      	PaymentRateDateType = @PaymentRateDateType,
      	PaymentRateDate = @PaymentRateDate
      where RadiusBills_Id = @RadiusBills_Id
   end

   insert RadiusBillsDealsElts(
      ActionId, ActionDatetime, DealLeg, RadiusBills_Id, BillCaptureMode, Price, Accrued, Price2, Accrued2, YTM)
   values (
      @ActionId, getdate(), @DealLeg, @RadiusBills_Id, 'C', @Price, @Accrued, @Price2, @Accrued2, @YTM)
end
go
__CMD_CHECK_PROC(RadiusBillsDeals_IU_CreateBill)

--------------------------------------------------------------------------

go
