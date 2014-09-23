__CMD_DROP_PROC(RadiusBillsDealsElts_D)
create procedure RadiusBillsDealsElts_D
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/* . Author: Evgeny Bugaev                                                                              */
/*                                                                                                      */
/* �������� ������� �� ������� RadiusBillsDealsElts. ���������� �� �������� ����������, �������� ������ */
/* � ���������.                                                                                         */
/*                                                                                                      */
/* 1. ��� ������� ���������� ������� �����������, ��� ��� �������� ���� ��������� ���������             */
/*    � ���� ��������.                                                                                  */
/* 2. ��������� ������ �� RadiusBillsBlanksActions - RadiusBillsBlanksActions_D                         */
/* 3. ������ ������� RadiusBillsDealsElts                                                               */
/* 4. ���� ������� �� ���� ������� � ���������� ���� ��������, �� �������������� �������                */
/*    �������� (RadiusBillsPositions).                                                                  */
/* 5. ���� ������� ���� ������� � ���������� ���� ��������, �� �� �������� ���������, �������           */
/*    �������� �� ��� ���������.                                                                        */
/* 6. ������� ����� ��������, ������� ����������� � ���� ��������                                       */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @RadiusBillsDeals_Id       numeric(15), -- ������
   @DealType                  char(1),     -- ��� ������
   @TradeDate                 datetime,    -- ���� ��������
   --
   @ErrorCode                 int             OUTPUT, -- 0 - OK, other - error code
   @ErrorMsg                  nvarchar(256)   OUTPUT

)
as

declare
   @RadiusBills_Id            numeric(15),
   @RadiusBillsDeals_Id_2     numeric(15),
   @err                       integer,
   @row                       integer

begin

   select @ErrorCode = -10, @ErrorMsg = '������������ ������!'

  select @TradeDate = convert(datetime, convert(varchar, @TradeDate, 112), 112)

  -- ��������� ��������� ������ �� ��������� �������
   insert into #Elts (RadiusBillsDealsElts_Id, DealLeg, RadiusBills_Id)
   select RadiusBillsDealsElts_Id, DealLeg, RadiusBills_Id
   from RadiusBillsDealsElts where  RadiusBillsDeals_Id = @RadiusBillsDeals_Id

   save transaction RadiusBillsDealsElts_D

-- 1. ��� ������� ���������� ������� �����������, ��� ��� �������� ���� ��������� ��������� � ���� ��������.
   select @RadiusBillsDeals_Id_2 = min(e2.RadiusBillsDeals_Id)
   from   #Elts e, RadiusBillsDealsElts e2, RadiusBills b
   where  e.RadiusBills_Id = b.RadiusBills_Id
   and    b.BatchOfBills = 'N'
   and    e.RadiusBills_Id = e2.RadiusBills_Id
   and    e2.RadiusBillsDeals_Id > @RadiusBillsDeals_Id -- �������� ������ ���� ��������� ������� ����� ���������

   if @RadiusBillsDeals_Id_2 is not null
   begin
      rollback transaction RadiusBillsDealsElts_D
      select @ErrorCode = -1, @ErrorMsg = '��������� �� ���� ������ ��� ��������� � ������ � ' + convert(varchar, @RadiusBillsDeals_Id_2)
      return @ErrorCode
   end

-- ������ ������� RadiusBillsDealsElts
   delete from RadiusBillsDealsElts
   where  RadiusBillsDeals_Id = @RadiusBillsDeals_Id

   if @@error <> 0
   begin
      rollback transaction RadiusBillsDealsElts_D
      select @ErrorCode = -1, @ErrorMsg = '��� �������� ������� �� ������� RadiusBillsDealsElts ��������� ������ (1)'
      return @ErrorCode
   end

-- 2. ���� ������� �� ���� ������� � ���������� ���� ��������, �� �������������� ������� �������� (RadiusBillsPositions).

-- ������� ��������� � ���������� ��������� ��������:
   if @DealType not in (__Bill_DealType_Own_Issue,
                        __Bill_DealType_Branch_Issue,
                        __Bill_DealType_ThirdParty_Buy,
                        __Bill_DealType_ThirdParty_RevRepo)
   begin
      -- ������� ����� ������� ������
      delete from RadiusBillsPositions
      from RadiusBillsPositions pos, #Elts e
      where  not (@DealType = __Bill_DealType_Own_Exchange and e.DealLeg = 'S'          -- ������ ����������� �������� � ���������� ����
               or @DealType = __Bill_DealType_Branch_Exchange and e.DealLeg = 'S'       -- ������ ����������� �������� � ���������� ����
               or @DealType = __Bill_DealType_ThirdParty_Exchange and e.DealLeg = 'B')  -- ������� ����� �������� � ���������� ����
      and    e.RadiusBills_Id = pos.RadiusBills_Id
      and    pos.HistDate >= @TradeDate

      if @@error <> 0
      begin
         rollback transaction RadiusBillsDealsElts_D
         select @ErrorCode = -1, @ErrorMsg = '��� ����������� ������� �� �������� ��������� ������ (1)'
         return @ErrorCode
      end

      -- ���������� ��������� ������
      update RadiusBillsPositions set
         HistDateNext = convert(datetime,'99990101', 112)
      from RadiusBillsPositions pos, #Elts e
      where  not (@DealType = __Bill_DealType_Own_Exchange and e.DealLeg = 'S') -- ������ ����������� �������� � ���������� ����
      and    not (@DealType = __Bill_DealType_Branch_Exchange and e.DealLeg = 'S') -- ������ �������� �������� � ���������� ����
      and    not (@DealType = __Bill_DealType_ThirdParty_Exchange and e.DealLeg = 'B') -- ��������� ����� �������� � ���������� ����
      and    e.RadiusBills_Id = pos.RadiusBills_Id
      and    pos.HistDateNext >= @TradeDate

      select @err = @@error, @row = @@rowcount

      if @err <> 0
      begin
         rollback transaction RadiusBillsDealsElts_D
         select @ErrorCode = -1, @ErrorMsg = '��� ����������� ������� �� �������� ��������� ������ (2)'
         return @ErrorCode
      end

      if @row = 0
      begin

         insert into RadiusBillsPositions (
            RadiusBills_Id, Folders_Id, BillStatus, HistDate, HistDateNext)
         select
            b.RadiusBills_Id,
            d.Folders_Id,
            case @DealType
               when __Bill_DealType_Own_Issue            then  ''
               when __Bill_DealType_Own_Buy2Mature       then  'I'
               when __Bill_DealType_Own_Buy2Sell         then  'I'
               when __Bill_DealType_Own_Mature           then  'I'
               when __Bill_DealType_Own_Sell             then  'i'
               when __Bill_DealType_Own_Exchange         then  'I'

               when __Bill_DealType_Branch_Issue         then  ''
               when __Bill_DealType_Branch_Buy2Mature    then  'I'
               when __Bill_DealType_Branch_Buy2Sell      then  'I'
               when __Bill_DealType_Branch_Mature        then  'I'
               when __Bill_DealType_Branch_Sell          then  'i'
               when __Bill_DealType_Branch_Exchange      then  'I'

               when __Bill_DealType_ThirdParty_Buy       then  ''
               when __Bill_DealType_ThirdParty_Sell      then  'B'
               when __Bill_DealType_ThirdParty_Mature    then  'B'
               when __Bill_DealType_ThirdParty_RevRepo   then  ''
               when __Bill_DealType_ThirdParty_DirRepo   then  'B'
               when __Bill_DealType_ThirdParty_Exchange  then  'B'
            end,
            @TradeDate, convert(datetime,'99990101',112)
         from  RadiusBills b, #Elts e, RadiusBillsDeals d
         where not (@DealType = __Bill_DealType_Own_Exchange and e.DealLeg = 'S' or
                    @DealType = __Bill_DealType_Branch_Exchange and e.DealLeg = 'S' or
                    @DealType = __Bill_DealType_ThirdParty_Exchange and e.DealLeg = 'B')
         and   e.RadiusBills_Id = b.RadiusBills_Id
         and   b.BatchOfBills = 'N'
         and   d.RadiusBillsDeals_Id = @RadiusBillsDeals_Id

         if @@error <> 0
         begin
            rollback transaction RadiusBillsDealsElts_D
            select @ErrorCode = -1, @ErrorMsg = '��� ����������� ������� �� �������� ��������� ������ (2.5)'
            return @ErrorCode
         end


      end


   end

-- 3. ���� ������� ���� ������� � ���������� ���� ��������, �� �� �������� ���������, ������� �������� �� ��� ���������.
-- ������� ��������� � ���������� ��������� ��������:

   if @DealType in ( __Bill_DealType_Own_Issue,
                     __Bill_DealType_Branch_Issue,
                     __Bill_DealType_ThirdParty_Buy,
                     __Bill_DealType_ThirdParty_RevRepo,
                     __Bill_DealType_Own_Exchange,
                     __Bill_DealType_Branch_Exchange,
                     __Bill_DealType_ThirdParty_Exchange)
   begin
      -- ������� ������ �� ������� ������� �� ��������� ��������
      delete from RadiusBillsPositions
      from RadiusBillsPositions pos, #Elts e
      where  not (@DealType = __Bill_DealType_Own_Exchange and e.DealLeg = 'B') -- ��������� ����������� �������� � ���������� ����
      and    not (@DealType = __Bill_DealType_Branch_Exchange and e.DealLeg = 'B') -- ��������� �������� �������� � ���������� ����
      and    not (@DealType = __Bill_DealType_ThirdParty_Exchange and e.DealLeg = 'S') -- ������� ����� �������� � ���������� ����
      and    e.RadiusBills_Id = pos.RadiusBills_Id
      and    pos.HistDate >= @TradeDate

      if @@error <> 0
      begin
         rollback transaction RadiusBillsDealsElts_D
         select @ErrorCode = -1, @ErrorMsg = '��� ����������� ������� �� �������� ��������� ������ (3)'
         return @ErrorCode
      end

      -- ������� ���� �������.
      delete from RadiusBills
      from RadiusBills b, #Elts e
      where  not (@DealType = __Bill_DealType_Own_Exchange and e.DealLeg = 'B') -- ��������� ����������� �������� � ���������� ����
      and    not (@DealType = __Bill_DealType_Branch_Exchange and e.DealLeg = 'B') -- ��������� �������� �������� � ���������� ����
      and    not (@DealType = __Bill_DealType_ThirdParty_Exchange and e.DealLeg = 'S') -- ������� ����� �������� � ���������� ����
      and    e.RadiusBills_Id = b.RadiusBills_Id
      and    not exists (select 1 from RadiusBillsDealsElts elts                 -- ���� �� ������������ � ������ ���������
                         where elts.RadiusBills_Id = b.RadiusBills_Id)

      if @@error <> 0
      begin
         rollback transaction RadiusBillsDealsElts_D
         select @ErrorCode = -1, @ErrorMsg = '��� �������� �������� ��������� ������ (1)'
         return @ErrorCode
      end

   end

-- 4. ������� ����� ��������, ������� ����������� � ���� ��������
   delete from RadiusBills
   from RadiusBills b, #Elts e
   where  e.RadiusBills_Id = b.RadiusBills_Id
   and    b.BatchOfBills = 'Y'

   if @@error <> 0
   begin
      rollback transaction RadiusBillsDealsElts_D
      select @ErrorCode = -1, @ErrorMsg = '��� �������� ����� �������� ��������� ������.'
      return @ErrorCode
   end


-- ������� �������� � �������� ��� ������� ����������� �������� �� RadiusBillsBlanksActions - RadiusBillsBlanksActions_D
   if @DealType in (__Bill_DealType_Own_Issue, __Bill_DealType_Own_Exchange)
   begin

      declare
         @RadiusBillsDealsElts_Id     numeric(15),
         @RadiusBillsBlanksActions_Id numeric(15),
         @Object_Id_a                 numeric(15)


      -- �������� �� �������� �������������� �������
      declare cBlanks cursor for
         select RadiusBillsDealsElts_Id from #Elts

      open cBlanks
      fetch cBlanks into @RadiusBillsDealsElts_Id

      while (@@sqlstatus = 0)
      begin
         select @RadiusBillsBlanksActions_Id = min(RadiusBillsBlanksActions_Id)
         from RadiusBillsBlanksActions where RadiusBillsDealsElts_Id = @RadiusBillsDealsElts_Id

         if @RadiusBillsBlanksActions_Id is not null
         begin
            exec RadiusBillsBlanksActions_D  @RadiusBillsBlanksActions_Id, null, @ErrorCode OUTPUT, @ErrorMsg OUTPUT, @Object_Id_a OUTPUT
            if @ErrorCode <> 0
            begin
               rollback transaction RadiusBillsDealsElts_D
               return @ErrorCode
            end
         end

         fetch cBlanks into @RadiusBillsDealsElts_Id
      end

      close cBlanks
      deallocate cursor cBlanks

   end

   select @ErrorCode = 0, @ErrorMsg = ''
end
go
__CMD_CHECK_PROC(RadiusBillsDealsElts_D)
drop table #Elts
go