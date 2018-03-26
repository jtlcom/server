defmodule Dresses do

    # 提升
    def essence(essence_id, {id, data}) do
        Dressup.essence(:dresses, essence_id, {id, data})
    end

    # 分解
    def breakup(breakup_id, count, {id, data}) do
        Dressup.breakup(:dresses, breakup_id, count, {id, data})
    end

    # 激活
    def active(active_id, {id, data}) do
        Dressup.active(:dresses, active_id, {id, data})
    end

    # 升星
    def raisestar(raise_id, {id, data}) do
        Dressup.raisestar(:dresses, raise_id, {id, data})
    end

    #穿戴
    def dress(dress_id, {id, data}) do
        Dressup.dress(:dresses, dress_id, {id, data})
    end

    #卸下
    def undress(undress_id, {id, data}) do
        Dressup.undress(:dresses, undress_id, {id, data})
    end

end