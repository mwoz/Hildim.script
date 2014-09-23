__CMD_DROP_PROC(RadiusBillsDealsElts_D)
create procedure RadiusBillsDealsElts_D
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/* . Author: Evgeny Bugaev                                                                              */
/*                                                                                                      */
/* Удаление записей из таблицы RadiusBillsDealsElts. Вызывается из операции добавления, удаления сделки */
/* с векселями.                                                                                         */
/*                                                                                                      */
/* 1. Для каждого отдельного векселя проверяется, что эта операция была последней операцией             */
/*    с этим векселем.                                                                                  */
/* 2. Удаляется запись из RadiusBillsBlanksActions - RadiusBillsBlanksActions_D                         */
/* 3. Чистим таблицу RadiusBillsDealsElts                                                               */
/* 4. Если векселя не были созданы в результате этой операции, то модифицируется история                */
/*    статусов (RadiusBillsPositions).                                                                  */
/* 5. Если векселя были созданы в результате этой операции, то их описания удаляются, история           */
/*    статусов по ним очищается.                                                                        */
/* 6. Удаляем пачки векселей, которые создавались в этой операции                                       */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @RadiusBillsDeals_Id       numeric(15), -- сделка
   @DealType                  char(1),     -- тип сделки
   @TradeDate                 datetime,    -- дата операции
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

   select @ErrorCode = -10, @ErrorMsg = 'Неопознанная ошибка!'

  select @TradeDate = convert(datetime, convert(varchar, @TradeDate, 112), 112)

  -- сохраняем удаляемые записи во временную таблицу
   insert into #Elts (RadiusBillsDealsElts_Id, DealLeg, RadiusBills_Id)
   select RadiusBillsDealsElts_Id, DealLeg, RadiusBills_Id
   from RadiusBillsDealsElts where  RadiusBillsDeals_Id = @RadiusBillsDeals_Id

   save transaction RadiusBillsDealsElts_D

-- 1. Для каждого отдельного векселя проверяется, что эта операция была последней операцией с этим векселем.
   select @RadiusBillsDeals_Id_2 = min(e2.RadiusBillsDeals_Id)
   from   #Elts e, RadiusBillsDealsElts e2, RadiusBills b
   where  e.RadiusBills_Id = b.RadiusBills_Id
   and    b.BatchOfBills = 'N'
   and    e.RadiusBills_Id = e2.RadiusBills_Id
   and    e2.RadiusBillsDeals_Id > @RadiusBillsDeals_Id -- операция должна быть ФИЗИЧЕСКИ ВВЕДЕНА самой последней

   if @RadiusBillsDeals_Id_2 is not null
   begin
      rollback transaction RadiusBillsDealsElts_D
      select @ErrorCode = -1, @ErrorMsg = 'Векселями из этой сделки уже участвуют в сделке № ' + convert(varchar, @RadiusBillsDeals_Id_2)
      return @ErrorCode
   end

-- Чистим таблицу RadiusBillsDealsElts
   delete from RadiusBillsDealsElts
   where  RadiusBillsDeals_Id = @RadiusBillsDeals_Id

   if @@error <> 0
   begin
      rollback transaction RadiusBillsDealsElts_D
      select @ErrorCode = -1, @ErrorMsg = 'При удалении записей из таблицы RadiusBillsDealsElts произошла ошибка (1)'
      return @ErrorCode
   end

-- 2. Если векселя не были созданы в результате этой операции, то модифицируется история статусов (RadiusBillsPositions).

-- векселя создаются в результате следующих операций:
   if @DealType not in (__Bill_DealType_Own_Issue,
                        __Bill_DealType_Branch_Issue,
                        __Bill_DealType_ThirdParty_Buy,
                        __Bill_DealType_ThirdParty_RevRepo)
   begin
      -- удаляем более поздние записи
      delete from RadiusBillsPositions
      from RadiusBillsPositions pos, #Elts e
      where  not (@DealType = __Bill_DealType_Own_Exchange and e.DealLeg = 'S'          -- выпуск собственных векселей в результате мены
               or @DealType = __Bill_DealType_Branch_Exchange and e.DealLeg = 'S'       -- выпуск филиальских векселей в результате мены
               or @DealType = __Bill_DealType_ThirdParty_Exchange and e.DealLeg = 'B')  -- покупка чужих векселей в результате мены
      and    e.RadiusBills_Id = pos.RadiusBills_Id
      and    pos.HistDate >= @TradeDate

      if @@error <> 0
      begin
         rollback transaction RadiusBillsDealsElts_D
         select @ErrorCode = -1, @ErrorMsg = 'При модификации позиции по векселям произошла ошибка (1)'
         return @ErrorCode
      end

      -- продлеваем остальные записи
      update RadiusBillsPositions set
         HistDateNext = convert(datetime,'99990101', 112)
      from RadiusBillsPositions pos, #Elts e
      where  not (@DealType = __Bill_DealType_Own_Exchange and e.DealLeg = 'S') -- выпуск собственных векселей в результате мены
      and    not (@DealType = __Bill_DealType_Branch_Exchange and e.DealLeg = 'S') -- выпуск векселей филииала в результате мены
      and    not (@DealType = __Bill_DealType_ThirdParty_Exchange and e.DealLeg = 'B') -- получение чужих векселей в результате мены
      and    e.RadiusBills_Id = pos.RadiusBills_Id
      and    pos.HistDateNext >= @TradeDate

      select @err = @@error, @row = @@rowcount

      if @err <> 0
      begin
         rollback transaction RadiusBillsDealsElts_D
         select @ErrorCode = -1, @ErrorMsg = 'При модификации позиции по векселям произошла ошибка (2)'
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
            select @ErrorCode = -1, @ErrorMsg = 'При модификации позиции по векселям произошла ошибка (2.5)'
            return @ErrorCode
         end


      end


   end

-- 3. Если векселя были созданы в результате этой операции, то их описания удаляются, история статусов по ним очищается.
-- векселя создаются в результате следующих операций:

   if @DealType in ( __Bill_DealType_Own_Issue,
                     __Bill_DealType_Branch_Issue,
                     __Bill_DealType_ThirdParty_Buy,
                     __Bill_DealType_ThirdParty_RevRepo,
                     __Bill_DealType_Own_Exchange,
                     __Bill_DealType_Branch_Exchange,
                     __Bill_DealType_ThirdParty_Exchange)
   begin
      -- удаляем записи из таблицы позиций по созданным векселям
      delete from RadiusBillsPositions
      from RadiusBillsPositions pos, #Elts e
      where  not (@DealType = __Bill_DealType_Own_Exchange and e.DealLeg = 'B') -- погашение собственных векселей в результате мены
      and    not (@DealType = __Bill_DealType_Branch_Exchange and e.DealLeg = 'B') -- погашение векселей филииала в результате мены
      and    not (@DealType = __Bill_DealType_ThirdParty_Exchange and e.DealLeg = 'S') -- продажа чужих векселей в результате мены
      and    e.RadiusBills_Id = pos.RadiusBills_Id
      and    pos.HistDate >= @TradeDate

      if @@error <> 0
      begin
         rollback transaction RadiusBillsDealsElts_D
         select @ErrorCode = -1, @ErrorMsg = 'При модификации позиции по векселям произошла ошибка (3)'
         return @ErrorCode
      end

      -- удаляем сами векселя.
      delete from RadiusBills
      from RadiusBills b, #Elts e
      where  not (@DealType = __Bill_DealType_Own_Exchange and e.DealLeg = 'B') -- погашение собственных векселей в результате мены
      and    not (@DealType = __Bill_DealType_Branch_Exchange and e.DealLeg = 'B') -- погашение векселей филииала в результате мены
      and    not (@DealType = __Bill_DealType_ThirdParty_Exchange and e.DealLeg = 'S') -- продажа чужих векселей в результате мены
      and    e.RadiusBills_Id = b.RadiusBills_Id
      and    not exists (select 1 from RadiusBillsDealsElts elts                 -- если не используются в других операциях
                         where elts.RadiusBills_Id = b.RadiusBills_Id)

      if @@error <> 0
      begin
         rollback transaction RadiusBillsDealsElts_D
         select @ErrorCode = -1, @ErrorMsg = 'При удалении векселей произошла ошибка (1)'
         return @ErrorCode
      end

   end

-- 4. Удаляем пачки векселей, которые создавались в этой операции
   delete from RadiusBills
   from RadiusBills b, #Elts e
   where  e.RadiusBills_Id = b.RadiusBills_Id
   and    b.BatchOfBills = 'Y'

   if @@error <> 0
   begin
      rollback transaction RadiusBillsDealsElts_D
      select @ErrorCode = -1, @ErrorMsg = 'При удалении пачек векселей произошла ошибка.'
      return @ErrorCode
   end


-- удаляем операции с бланками при выпуске собственных векселей из RadiusBillsBlanksActions - RadiusBillsBlanksActions_D
   if @DealType in (__Bill_DealType_Own_Issue, __Bill_DealType_Own_Exchange)
   begin

      declare
         @RadiusBillsDealsElts_Id     numeric(15),
         @RadiusBillsBlanksActions_Id numeric(15),
         @Object_Id_a                 numeric(15)


      -- операции по списанию использованных бланков
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